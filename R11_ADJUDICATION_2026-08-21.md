# R11 裁定书 — 2026-08-21

## 一句话裁定

**R11 是项目历史上第一次实证确认的写落地：rb_erase 写原语成功把受控值写进了 perf 泄露任务的 real_cred（task+0x778），写机制全程成立；死于载荷内容（假 cred 的 security 字段在被解引用时为 NULL），不是死于写不进。** 假 cred 地址精确值待 R11.out 重收后终裁（H1 喷页回收清零 vs H2 地址错位）。

## 一、时间线（全部有落盘证据）

| 时刻 | 事件 | 证据 |
|---|---|---|
| 19:23:43 | 卡6 v4 启动：mt61 部署，SHA `19e8f636...` 校验通过 | card_console_20260821_192343.log L5-8 |
| 19:23-19:24 | 取证零残留（线程行数=0）；体检过：boot `0ccbcac1`、Enforcing、settle OK、load 12.47（仅记录） | 同上 L9-14 |
| 19:24 | R11 开火（stage=R, PTR_RIGHT=auto, WINDOW=20s, 无 PSELECT_TASK → 子进程自瞄） | fire R11 R ""（field_auto.sh L162） |
| 19:24 | `R11.out` 1932 字节 + `mt49_child_status.txt` 落盘（`task=ffffff827f581280 uid=2000 euid=2000 CapEff=0 root_seen=0`，mt51 fsync 生效） | tmp_listing.txt；mt49_child_status.txt |
| [16351.365] | 内核 NULL 解引用 @ 0x4，`selinux_task_to_inode+0x58`，PID 28687 Comm=sleep | SYSTEM_LAST_KMSG（dropbox） |
| ~19:25:00 | 设备自发重启（uptime 304.51s @ 19:30:05 倒推） | device_state.txt |
| 19:26:13 | 新 boot 的 dropbox 记录 `Last boot reason: kernel_panic`（isPrevious: true） | SYSTEM_BOOT / SYSTEM_LAST_KMSG |
| 19:29:34 | 用户跑 recover.sh（零开火回收），推回仓库 | commit 6f89ce6 |

recover.sh 旧 bug 复现：`R11_raw.out`/`pstore_tail.txt` 各只收到 1 字节（首笔 rsh 闪断被误判成功）——但 `dropbox_tail.txt`（200KB）完整携带了 mrdump panic 记录，**定罪证据反而一分没丢**。设备上 1932 字节的 R11.out 仍在（重启不清 /data/local/tmp），等 recollect_r11.sh 字节校验重收。

## 二、Panic 现场完整解码

### 2.1 崩溃头

```
Unable to handle kernel NULL pointer dereference at virtual address 0000000000000004
ESR = 0x96000005 (EC=0x25 DABT current EL, WnR=0 读)
pc : selinux_task_to_inode+0x58  (0xffffffe1a30c4d88)
lr : pid_update_inode+0x188
CPU: 0  PID: 28687  Comm: sleep   ← /system/bin/sleep 180 + LD_PRELOAD=preload.so
Tainted: P S WC O  5.10.209-android12-9-...  Hardware: MT6983Z/CZA
```

### 2.2 寄存器（关键组）

```
x0  = ffffff827f581280   ← task（= mt49_child_status 的 task=，铁证闭环）
x1  = ffffff825df5f768   ← /proc inode
x8  = 0                  ← tsec（崩溃源）
x10 = 0                  ← selinux blob offset = 0
x6/x7 = 0x3738363832     ← ASCII "28687"（正在解析的 dentry 名）
```

X12 dump 中出现 dentry 名字符串 `38363832 00000037` = "28687\0"——**崩溃时正在解析的路径是 `/proc/28687/...`，即 mt49 子进程自己的 /proc 条目**（mt49 轮询自身 status）。

### 2.3 崩溃指令链（disasm_r11.py 裁定，与寄存器吻合）

```
4d68: add  x8, x0, #0x778    x8 = &p->real_cred          (x0=task)
4d6c: ldapr x8, [x8]         x8 = p->real_cred           (成功读出——写入已落地)
4d70: ldr  x8, [x8, #0x78]   x8 = real_cred->security    ← 读出 0
4d84: add  x8, x8, x10       tsec = security + 0
4d88: ldr  w22, [x8, #4]     sid = tsec->sid             ← FAULT @ 0x4
```

注意 4d6c/4d70 都是成功执行的访存：real_cred 本身是合法可读内核地址（若是垃圾地址，崩溃点会在 4d70 且 fault 地址=real_cred+0x78 而非 0x4）。**即 real_cred 指向一块映射完好、但 +0x78 处为 0 的内存。**

### 2.4 Call trace

```
el0_sync → openat → do_sys_openat2 → do_filp_open → path_openat
→ link_path_walk → walk_component → lookup_fast → pid_revalidate
→ pid_update_inode → selinux_task_to_inode+0x58  ← 崩
→ el1_sync → do_mem_abort → do_translation_fault → do_page_fault
→ __do_kernel_fault → die_kernel_fault → die → ipanic_die [mrdump]
```

mrdump 全程介入 = `Last boot reason: kernel_panic` 的来源。用户确认非手动重启，与 mrdump 记录互证。

## 三、裁定推理

### 3.1 写落地成立（项目首次）

1. `x0 = ffffff827f581280` 与 `mt49_child_status.txt` 的 `task=` 完全一致——崩溃任务就是 stage-R 的写入目标（perf 泄露的 mt49 子进程本体）。
2. 崩在 `real_cred->security` 的解引用链上（4d6c 成功读出 real_cred 值）——**该字段的值已被换成受控写入值**。原版 cred 的 security 永远非 NULL（SELinux 每个 cred 都有 blob），读到 NULL 只可能是字段被改后指向了错的对象。
3. 写入值（right_env = 喷页假 cred 地址，PTR_RIGHT=auto 模式）指向一块可读、+0x78 为 0 的内存——与"喷页被回收清零"或"地址指向了从未写过假 cred 的页"两种形态都吻合。
4. 触发链闭环：mt49 子进程每 200ms 轮询自身 status → 写落地后下一次 openat("/proc/28687/status") → pid_revalidate 用被改写的 real_cred 走 SELinux → 崩。状态文件冻结在落地前最后一帧（CapEff=0），Panic 与状态文件 mtime（均 19:24）吻合。

### 3.2 死因两假说（待 R11.out 终裁）

| 假说 | 机制 | 预期 R11.out 特征 |
|---|---|---|
| H1 喷页回收清零 | 喷页 skb 在 PTR 开火前/后被释放，页被回收清零（Android GKI 常开 init_on_free），security 读 0 | right= 与喷页行一致；reclaim/释放标记在写前 |
| H2 地址错位 | mt55 公式（page_base+SKB_DATA_DELTA+0x3800）与 util.c 实写地址不同源/不同页；或无喷页轮回落 | right= 异常（无 [PTR_RIGHT auto] 标记 / page_base 空） |

两假说崩溃签名相同（都可读、+0x78=0），只能靠 R11.out 的 `mt48: PTR` 行（pc/right/标记）+ 喷页行分辨。**1932 字节的 R11.out 还在设备上，recollect_r11.sh 字节校验重收是当前唯一待办。**

### 3.3 检测通道悖论（机器门盲区）

`gate()` 以 CapEff≠0 判 R_LANDED——但检测动作（读 /proc/self/status）本身就是解引用 real_cred->security 的路径。**载荷 security 无效时，"检测落地"与"内核必崩"是同一个动作**：落地永远表现为 panic 而非状态文件翻转。这就是 R11 门 froze 在 CapEff=0 的原因。结论：任何 PTR 载荷都必须保证 security 指针有效，否则成功=自杀。

## 四、对 mt62 的指向

1. **写原语免检**：EDEADLK 快路 → rb_erase → parent 槽写入（pc+8=task+0x778）→ 受控值落地，全链路实证成立。mt62 不应再动写路径。
2. **假 cred 必须带有效 security**。两个方向：
   - 方向 A（回 init_cred）：init_cred.security 指向 boot 期分配的合法 blob（sid=kernel），real_cred=&init_cred 后 selinux_task_to_inode 读 sid=1 不崩，CapEff/uid 全满，检测通道存活。mt54 时代"init_cred 2/2 致死"的旧警告已被本项目历史复核证伪（那批崩溃实为签名A rt_mutex_adjust_prio_chain 毒树遍历，与 init_cred 无关）——而 R11 证明真正会炸的恰是为了规避它换上的喷页假 cred。残余风险：子进程退出时 put_cred 会递减 init_cred.usage（慢燃，非即崩），mt62 需配"落地后子进程永驻不退"或恢复策略。
   - 方向 B（修喷页）：若 R11.out 判为 H1 → 保持喷页存活不回收；若 H2 → 修地址同源。
3. **先收证据再动刀**：mt62 开工前置条件 = R11.out 到手（right 精确值 + 喷页几何 + 尝试序号）。

## 五、证据索引

- `logs_raw/R11/pstore_lastkmsg_full.txt` — SYSTEM_LAST_KMSG 全文切档（583 行，含完整寄存器组/PC/LR 反汇编窗口/栈帧）
- `logs_raw/recovery_20260821_192934/dropbox_tail.txt` — 200KB 原始尾巴（panic 记录在其中 1815-2397 行）
- `logs_raw/recovery_20260821_192934/mt49_child_status.txt` — 落地前最后一帧（task= 闭环锚点）
- `logs_raw/recovery_20260821_192934/card_console_20260821_192343.log` — 卡6 控制台（截断于"开始开火"）
- `logs_raw/recovery_20260821_192934/device_state.txt` — 新 boot_id `a5f88675`、Enforcing、uptime 304.51
- `disasm_r11.py`（work 目录）— selinux_task_to_inode 反汇编与数据流裁定

## 六、下一步（唯一待办）

用户侧跑 recollect_r11.sh（只读、字节校验、零开火）→ 拉 1932 字节 R11.out → 终裁 H1/H2 → mt62 立项。
