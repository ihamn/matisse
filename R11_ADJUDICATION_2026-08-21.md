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

---

# 七、R11.out 终裁（2026-08-30 01:15，r11v2_20260830_011545）

1932B 与 911B（mt62 轮）两个 panic 轮 R11.out 均**全 NUL**（md5 双端一致）。机制：stdout 只 fflush 无 fsync，panic 重启后 f2fs 仅恢复 inode 尺寸、数据页丢失。**runlog 通道对 panic 轮判死，不再投入回收轮。** H1/H2 之争随之作废，mt62 锁定方向 A：载荷从喷页假 cred 换 init_cred（dmap 别名 `ffffff80027b0ae0`，Δ=0 已实证），二进制零改动（mt54 时代既有 `[PTR_RIGHT override]` 路径）。交付：sed 一行粘贴（base64 行在聊天生成时截断损坏，弃用）。

# 八、mt62 两轮纵向（同一 mt61 二进制）

| 轮 | 载荷 | R 写 | 结局 |
|---|---|---|---|
| R11 (mt61) | 喷页假cred | 落地 | panic: selinux_task_to_inode @0x4（载荷 security=NULL 内容死）|
| mt62-r1 (08-30 00:59) | init_cred | 未落地 | panic: 毒树走查 rt_mutex_adjust_prio_chain+0x548（假节点窗口期，写原语自身副作用，与载荷无关）|
| mt62-r2 (08-30 09:09) | init_cred | **落地且存活** | **无 panic**，rc=3 惰性退出；C1 未获开火（见九）|

# 九、mt62-r2：R_LANDED 首次达成 + C1 近失裁定（本轮头条）

**里程碑：写原语 R 阶段首次在同轮内存活落地。**

事实链（logs_raw/ea7592b，全一手）：
- 09:09:35 卡启动，mt61 SHA `19e8f636` 校验通过，boot `639bb902`，Enforcing，负载 13.79（高负载下照样落地 — mt61 窗口 20s 设计兑现）
- R11 轮 runlog 91 行**完整存活**（首次非 NUL — 因为没 panic）
- `mt48: PTR stage=R task=ffffff82626aa500 right=ffffff80027b0ae0 [PTR_RIGHT override]` — mt62 载荷确认在用
- 写落地实证：mt47 子进程自 poll=50 起持续 `CapEff=000001ffffffffff`（满帽）至 poll=1300 — **real_cred=init_cred 存活 260+ 秒，设备零崩溃，Enforcing 全程**
- `uid=2000`（cred 指针未换 = 半程态，与 mt48 AND-gate 设计完全一致：CapEff 满帽∧euid==0 才动手，半程态结构性不触发 commit_creds BUG_ON）
- 路由 STALL（route_done>12s）→ rc=3 惰性轮退出 — C 阶段本轮内未触发（真方差，非 bug）
- 门槛判定 R_LANDED（CapEff≠0）→ 正确

**C1 弃打 = 本轮唯一败因（脚本 bug，已修 mt63）：**
- fire() 先调 cleangate()：rm `mt49_child_status.txt`+`root_alive.txt` 后 ls 验证
- 但 `mt49_child_status.txt` 是**活体 R11 子进程每 200ms fsync 重写的**（main.c:719-727）— rm 后瞬间复活 → 残留 1 → 重试 4 次全败 → "删不净, 弃打本轮"
- 讽刺闭环：删不掉的文件正是门槛刚读出 R_LANDED 的那个文件；它删不掉恰恰证明写目标（活体子进程）还活着 — **这正是该开火的信号，却被当成污染信号**
- 时间线证明窗口本足够：子进程窗口 = fork 后 480s（2400×200ms）；R11_RC 约在 fork 后 ~100s 返回；C1 若按时开火（prep ~2min）写落地在窗口内还剩 ~4min 余量 — **此 bug 单独毁掉了史上最接近的一掷**

# 十、mt63 修复（field_auto.sh 单点改动，二进制不动）

fire() 外部模式（task≠空，即 C1 补轮）跳过 cleangate：活体子进程正在写的状态文件不是污染，是活体遥测；仅清 root_alive.txt（本轮内不可能由子进程创建 — gate 需 euid==0，C 写未落地前不可能；其存在只可能是旧轮残留）。R11/R12 内部模式（task=空）行为不变。证据标记：C1 开打时 console 出现 `[mt63] C1 外部模式: 不清状态文件...`。sed 一行已验证：产出与正本逐字节一致 / bash -n / 幂等 三项全过。

# 十一、下一掷判定树

R_LANDED → C1 开火（prep~2min, 窗口余量~4min）→ C 写落地 → 子进程 AND-gate（CapEff满∧euid=0）命中 → setresuid(0,0,0) → commit_creds（两指针相等, BUG_ON 通过）→ root_alive.txt → 项目终局。C1 仍掷同款毒树骰子：panic → recover.sh → 重掷；落地 → win。R_MISS → R12 重掷（脚本既有逻辑）。

# 十二、mt63-r1 (09:26) 裁定 + mt63-v2（2026-08-30）

**本轮：R11 惰性未中（真方差）+ R12 被 cleangate 同款 bug 卡掉（v1 未覆盖内部模式）。**

- R11：mt48 PTR 行正常打出（stage=R right=ffffff80027b0ae0），但 route STALL（route_done>12s，竞速输了）→ rc=3 惰性退出，子进程 1200+ 次轮询 CapEff=0。与 09:09 轮（落地）同二进制同载荷同负载量级 → 纯竞速骰子，1中1不中，符合方差。
- R12：**弃打于 cleangate**——R11 的孤儿子进程在 480s 轮询窗内每 200ms fsync 重写状态文件（runlog 实证活到 poll=1200+），rm 删了立即复活 → 残留 1×4 → "删不净, 弃打"。v1 只修了外部模式（C1），R12 内部模式仍走 cleangate → 同坑二次踩。
- mt63-v1 已确认在手机生效（c11525e 的 field_auto.sh 含 mt63 标记）。
- **mt63-v2 修复**：cleangate 的 rm 前加 `pkill -9 -x sleep`——孤儿是 shell UID、comm 精确为 sleep 的遗留进程（pkill 同 UID 才杀得动，Termux 侧 sleep 是别的 UID 动不到，安全）；上一轮结果已在 gate 读取时定格，杀孤儿零证据损失。C1 外部模式不经 cleangate（v1 已跳过），写目标子进程不会被误杀。sed 三项验证过（与正本逐字节一致/bash -n/幂等）。

## 下一步判定树（不变）

R_LANDED → C1 开火（mt63 v1+v2 全护）→ C 写落地 → AND-gate → setresuid(0,0,0) → root_alive.txt 终局；R_MISS → R12 重掷（这次不会被卡）；再 MISS → 按卡停止，隔时段再跑。

# 十三、09:43 轮裁定 + mt64：mt51 假阳性致 C 写只拿 1/6 发（2026-08-30）

**里程碑：R_LANDED → C1 首次真正开火（mt63 v1+v2 双护），双写阶段全打通；败因 = mt51 发间检查在 C 阶段的结构性假阳性。**

事实链（8aff70a，全一手）：
- R11 轮：R 写落地（mt48 stage=R right=ffffff80027b0ae0），子进程 poll=100 起 CapEff=000001ffffffffff 持续满帽，rc=3 惰性退出，无 panic
- gate 判 R_LANDED → C1 外部模式正常开火（console 有 [mt63] 标记，cleangate 不再误杀）——mt63 v1+v2 修复全部兑现
- C1 轮：mt49 external task=ffffff80db77a500（与 R11 子进程同 task ✓），mt48 stage=C pc=task+0x778 → STORE→[task+0x780 cred]（几何正确）
- **败点**：`mt25: futex trigger 0` 后紧跟 `mt51: mid-burst landing (CapEff=000001ffffffffff root=0) - abort shots ti=1`——6 连发只打了 1 发
- **根因（slide.c:407-427）**：mt51 发间检查读 mt49_child_status.txt，中止条件 `CapEff>=满帽 || root_seen`。该签名是 **R 写的**（status 读 real_cred）；而 C1 开火的前提恰恰是 R 写已落地 → 文件里 CapEff 恒满帽 → **条件在 C 阶段恒真，首发后必假阳性中止**。C 写的落地签名应是 euid==0（cred 已换）或 root_seen=1，代码没区分阶段
- 后果实证：R11 子进程在 C 写尝试后 90+ 秒（poll=900→1350）仍 uid=2000——cred 未换，1 发不够中
- 结构性：不修则**每一轮 C1 都只拿 1 发**（假阳性必然触发），C 写命中率被砍到 1/6

**mt64 修复（零二进制，fire() 两处）**：
1. 外部模式分支：清 root_alive 后追加 `chmod 000 mt49_child_status.txt`——mt51 的 open(O_RDONLY) 因 owner 无读位失败 → 检查整体跳过 → **6 发全打**（等效于 stage R 轮的实证安全 profile：09:09/09:43 两轮 R 写均 6 发全打+中途落地+零 panic）。R11 子进程不受影响：gate 判定读 /proc/self/status+getresuid（与该文件无关），其状态写 open 失败仅静默跳过（main.c:719 `if (sfd>=0)`），gate 命中后 setresuid(0,0,0) 以 root 身份写 root_alive.txt（root 绕过 DAC，该文件本就 0644）
2. cmd 尾部：`mtc64rc=\$?; chmod 644 ...; echo "${name}_RC=\$mtc64rc"`——正常/外层超时退出均恢复可读，第 6 步遥测照收（若 gate 已命中，子进程此刻 uid=0/euid=0/root_seen=1 会一并落进 mt49_status_final.txt）
- 已接受权衡：C1-panic 轮 recover.sh 读不到状态文件（mode 000 残留）→ 损失该轮冻结帧；dropbox panic 栈不受影响仍是主裁定通道，下一轮 cleangate rm（unlink 不看文件 mode）+ 子进程重建 0644 自愈
- sed 投递三项验证过（与正本逐字节一致/bash -n/幂等）；**教训已吃**：替换文本含 `2>&1`，`&` 在 sed 替换侧是"整个匹配"元字符必须写 `\&`（首验即抓到，输出 `2>…1` 损坏）

**下一掷判定树**：R_LANDED → C1（console 见 [mt64] 标记 + C1_raw.out 见 6 条 mt25 trigger = 致盲生效）→ C 写 6 发任中 → 子进程 AND-gate（CapEff满∧euid=0）→ setresuid(0,0,0) → root_alive.txt（pid/uid=0/euid=0/满帽）= 项目终局。R_MISS → R12 重掷。C1 panic → recover.sh（冻结帧或损，dropbox 栈为准）→ 重掷。

# 十四、10:07 轮裁定：C1 惰性（路由 STALL 于风暴前，0 发）— 2026-08-30

**mt64 交付验证 + R 写第 3 次落地；C 写未中于"风暴没跑"，非新 bug。**

- R11 轮：R_MISS（惰性）；R12 轮：R 写落地（mt48 stage=R，CapEff 满帽自 poll=50 起，rc=3 STALL，无 panic）→ R 落地累计 3 次（09:09/09:43/10:07）
- C1：mt64 标记出现（console 实证），致盲+恢复链路正常（收尾冻结帧可读 = chmod 644 恢复生效）；mt48 stage=C 几何正确；**但路由 STALL 于 mt19b 之前 → mt25 计数=0、mt19b 计数=0 → 一发未打**。requeue EDEADLK（errno=35）已触发但消费风暴未排入 → 无树走查 → 无 erase → 无写。与 R 轮惰性同源（路由完成率 ~50%，09:26 两轮同款）
- 冻结帧：`task=ffffff81ee764a00 uid=2000 euid=2000 CapEff=000001ffffffffff root_seen=0` — R 落地、C 未中、无 root
- **关键统计（路由完成→R 写落地：3/3）**：09:09/09:43/10:07 三轮 R 落地全发生在路由完成的轮次（mt19b+6×mt25 全打）；两次惰性轮全未中。推论：每发走查命中 ~20-30%，7 次走查（mt19b+6 发）累计接近必中。C1@09:43 仅 1-2 次走查未中与此一致
- **mt64 的真正考验还没到来**：需要一轮"C1 路由完成 + 风暴全跑"——预期 C1 日志出现 mt19b 行 + mt25 trigger 0..5 六行且无 mt51 中止行
- 裁定：纯方差，无需新补丁。重掷即可。判定树不变

## 12. mt65 (2026-08-30 下午): 卡内 R13/R14 续打 — 骰子密度优化

用户诉求: 连续重掷 1 小时+, 求提速。评估过 "C1 多试几次" 并否决: C 写目标是已落地 R 子进程, 存活窗 480s 硬编码(2400 poll x 200ms, main.c:605); C1 自身准备耗时 ~150-250s, C2 再来一轮时目标子进程已死, erase 写进已释放 task_struct = 把干净未中升级成 panic。一进程一写(crash#2)与半程毒态风险均不变。

采纳方案: 弃卡条件从 "两轮未中" 放宽到 "四轮未中"。R11 未中→R12 未中→R13→R14, 任一轮 R_LANDED 即转 C1(mt64 六发全打不变)。单卡至少一轮 R 落地概率 50%→93.75%; 期望卡时长 ~10min(期望 2.5 个 R 轮 + C1), 最坏 ~17min。相比重开卡(每次重付部署+取证 ~2min 且只保底 2 轮), 骰子密度显著提升。R13/R14 为内部模式, cleangate(mt63-v2 pkill)会清掉上一轮未落地孤儿, 与 R11/R12 同构安全。

脚本改动(仅 termux/field_auto.sh, 二进制零改动): line177 else 分支替换为 R13/R14 嵌套续打; line183 回收列表扩 R11 R12 R13 R14 + mkdir logs_raw/R13 R14。验证: sed 产出与正本逐字节一致 / bash -n / 幂等三项全过(mt64 补丁保留, grep -c R13=2 R14=2)。

### mt65-r1 补记 (用户确认): Shizuku 中途死亡的根因 = 息屏

用户确认卡运行中手机息屏。时间线吻合: R12/R13 尾部 getenforce=Enforcing(会话活着), R14 尾部 getenforce="Server is not running"(Shizuku 已死), 第6步全部回收为 1 行错误信息。R11 的 CONTAMINATED(外层超时)疑似同因早期息屏或独立会话故障。

防复发: 开发者选项开启"充电时保持唤醒"(Stay awake while charging)+全程插电; 或每次开卡前把息屏超时调到 10 分钟以上。注意 termux-wake-lock 只保 CPU 不保屏幕 — 此前 6 张卡能完整跑完是因屏幕全程亮着。

裁定不变: R12/R13 惰性确证, R11/R14 待 recover.sh 回收 R14_raw.out + mt49_child_status.txt 冻结帧判读。
