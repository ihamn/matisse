# E5 几何指令级实证 + mt74 全链行动方案（2026-09-04）

> 结论先行：**E5（selinux enforcing 零写）几何已在指令级完全验证，补丁已写入
> main.c（mt74 分支，`PSELECT_SELINUX_ENF=1`）。它是全链 root 的第一发：
> permissive 后 C 写不再致盲、finit_module 放行，剩下全是已验证/已写好的步骤。**

## 一、写几何（rb_erase @ 0xffffffc008a71228 反汇编，全部实证）

CASE_A 路径（TREE_LEFT=0 时进入，`cbz x9` @+0x8）：

```
0x278: ldr  x9, [x0]           ; pc = word0 (TREE_PC)
0x27c: ands x10, x9, #-4       ; parent = pc & ~3
0x288: ldr  x12, [x11, #0x10]! ; x12 = *(parent+0x10)   ← 判别字
0x28c: sub  x13, x11, #8       ; x13 = parent+8         ← 写目标
0x290: cmp  x12, x0            ; *(parent+0x10) == node?
0x294: csel x11, x11, x13, eq  ; ne → 写 parent+8（必然，判别字是随机内核数据）
0x298: str  x8, [x11]          ; ★STORE(a): *(parent+8) = child(word1=TREE_RIGHT)
0x29c: cbz  x8, 0x360          ; ★child==0 → STORE(b) 跳过（NULL 守卫实证）
0x2a0: mov  x10, xzr           ; child≠0 → 永不 rebalance
0x2a4: str  x9, [x8]           ; STORE(b): *(child+0) = pc
...
0x360: sbfx x8, x9, #0, #1     ; child==0 路径: 提取 pc bit0
0x364: and  x10, x8, x10       ; bit0==1(RB_BLACK) → rebalance(parent) → 旋转
0x368: cbnz x10 → __rb_erase_color
```

E5 配置 → **单条 8 字节零写** `*(selinux_state_alias + 0) = 0`：

| 词 | 值 | 作用 |
|---|---|---|
| TREE_PC | `(selinux_alias-8) & ~3` = `0xffffff8002a41b90` | parent=selinux-8；**必须 bit0=0（RED）** |
| TREE_RIGHT | 0 | child=0 → STORE(b) 跳过、永不旋转 |
| TREE_LEFT | 0 | 走 CASE_A |
| PI 三词 | 0（复位块默认） | pi erase 走 root 无害路径（R/C 轮同款，7/7 实证） |

★颜色修正（重要）★：upstream `RB_RED=0 / RB_BLACK=1`。fops.c 老注释
"0xffffff8002a41b91 RED 已置位"是**反的**——`|1` 恰是 BLACK，child=0 时会进
`__rb_erase_color(parent)` 旋转，把 SELinux 区当树节点读改写 = 致命。mt74 用
`& ~3`。R 几何（task+0x770，bit0=0，child≠0）7/7 无旋转是同构佐证。

顺带验证了 C 几何判别字：C 的 parent=task+0x778 → 判别字 = `*(task+0x788)`（初值
0 ≠ node）→ 必写 parent+8 = task+0x780 ✓。R 的判别字 = `*(task+0x780)`=cred ≠
node → 必写 task+0x778 ✓。与 9/1 CHECKPOINT 推导一致，现在有指令级出处。

## 二、enforcing 位置实证（推翻 upstream +1 假设）

- `avc_denied+0x1c`（@0xffffffc0088bb12c）：`ldarb w12, [x0]` + `tbz w12, #0`
  → **整个 enforcement 决策 = 读 state+0 的一个字节**。x0=state（sel_write_enforce
  调 avc_has_perm 时 adrp+add #0xb98 实证 x0=0xffffffc00aa41b98=selinux_state）。
- Android 重排了 struct：**enforcing@+0**（upstream 是 +1）。allow 路径
  `ldr x0, [x0, #0x48]` = state->avc → avc 指针在 +0x48，8 字节零写(+0..+7)
  碰不到任何指针，只清 enforcing/checkreqprot/initialized/policycap[0..3]。
- 8 字节窗口无法避开 initialized（enforcing 与它同窗）——接受：initialized=0 是
  "pre-policy" 态，多数钩子早退 allow，方向一致（更宽松，不会更严）。

## 三、mt74 行动序列（现场按序执行）

**每轮前置**：loadavg 1min < 10；屏幕常亮插电；部署 mt74 构建（含
PSELECT_SELINUX_ENF 分支的 main.c，Makefile 不变）。

**第 0 步（顺手，零成本）**：`dmesg | grep avc | grep -w kernel | tail -20`
—— 历史 C 轮若留下 kernel 域 denied = "C 写落地+致盲"理论的直接铁证，存档。

**第 1 步 E5 轮**：`PSELECT_CRED=1 PSELECT_SELINUX_ENF=1`（其余风暴参数与
R 轮一致：6 发、20s 窗口、watchdog 28s）。
- 验证：`cat /sys/fs/selinux/enforce` → **0**。
- 日志特征：`mt74: SELINUX_ENF write pc=ffffff8002a41b90`。
- 未落地（仍 1）→ 重试 1-2 轮；仍失败 → 收集 .out + dmesg 回来分析。
- 落地后系统 permissive：avc 日志会刷屏（正常），SELinux 不再拒任何操作。

**第 2 步 R 轮**：`PSELECT_CRED=1 PSELECT_PTR_MODE=1 PSELECT_PTR_PC_OFF=0x770
PSELECT_PTR_STRICT=1` + full storm。
- 验证：mt49_child_status.txt 的 CapEff 满 + 心跳正常（permissive 下全可见）。
- 记下 child task 地址（status 文件第一字段）。

**第 3 步 C 轮**（R-child 8 分钟窗口内，新进程）：`PSELECT_CRED=1
PSELECT_PTR_MODE=1 PSELECT_PTR_PC_OFF=0x778 PSELECT_PTR_STRICT=1
PSELECT_TASK=<R-child task>`。
- R-child 侧：sticky CapEff 已置 → C 落地 euid=0 → gate 命中 → setresgid/
  setresuid（cred==real_cred==init_cred，BUG_ON 通过）→ **ROOT-SEEN +
  hostname=glroot + root_alive.txt**。
- 备用几何：若主树 C 仍不落地，改 `PSELECT_PTR_PI=1`（E4 pi 路径）。

**第 4 步 KSU**：第 3 步同轮给 R-child 挂 `PSELECT_KO=<ko 路径>` → gate 后
finit_module（flags 0→3 vermagic bypass）→ ksu_done.txt。

**证据包**：hostname 输出、root_alive.txt、ksu_done.txt、两轮 .out、dmesg
avc 段、/proc/<R-child>/status（Uid: 0 0 0）。

## 四、风险与回退

- E5 后 system_server 可能因 SELinux 状态异常重启一次（framework 读 enforce=0）；
  不影响已 root 进程。全恶 → 物理重启即恢复（selinux_state 开机重载）。
- 每轮间 load gate；consumer 0 发即停（老规矩）。
- C 轮失败不炸机：STRICT gate 半程态不触发，BUG_ON 免疫（mt48 设计）。

## 五、为什么 E5 必须先行（不可跳过）

root 进程的 SID 是 kernel（init_cred->security 被 prepare_creds 拷贝）——
enforcing 下 root 也开不了文件、insmod 不了。E5 是唯一让 root 「有用」的路，
且它顺带复活全部检测通道（permissive → C 写不再致盲）。mt73 的无文件信标
（sethostname）作为 permissive 失效时的冗余保留。

## 六、E5 现场结果 + 黑屏归因（2026-09-05，commit 75b01e2）

**结果：E5 落地确认** —— `mt74 pc=ffffff8002a41b90` 打出后 6 发全触发
（t=12515-12656ms 正常窗口），跑完 `/sys/fs/selinux/enforce` 读 **0**。E5 轮
自身干净收尾（mt47 心跳到 250、uid=2000 CapEff=0 符合预期——E5 不碰 cred，
"no root" 是本轮目标外）。

**写足迹复核（对照 R 轮 7/7）**：仅 selinux_state+0..+7 被 STORE(a) 清零；
判别字读 *(state+8)、child=0 跳过 STORE(b)（cbz 守卫）、pc bit0=0 不旋转、
pi_tree 零词走 root 无害路径——全部与设计一致，无附带破坏。task-board
inode 损坏更可能是风暴/软重启的 fs 压力（9/3 已有先例），非本写所致。

**黑屏归因（静态部分）**：
1. `security_compute_av` @0xffffffc0088e0b30 实证：`ldarb w8,[state+2]; tbnz`
   → **initialized = state+2，在清零窗内** → compute_av 早退 `allowed=0xFFFFFFFF,
   auditallow=0` → **静默 allow-all，零 AVC 日志** → 排除"日志风暴打死系统"假说。
2. 故黑屏只剩两个候选：**(a) 框架/厂商对 permissive 的反应**（watchdog/反篡改，
   我们的裸写绕过了 status_page 同步，框架的 mmap 缓存仍是 enforcing=1，行为
   不一致可能触发异常路径）；**(b) 风暴自诱导软重启**（9/3 无 E5 也发生过，
   load 1067 历史）。**判定证据 = pstore**。
3. 好消息：无日志洪泛 → E5 后系统安静，窗口足够长（现场 cat enforce 成功、
   E5.out 心跳持续写出都证明进程侧存活）。

## 七、mt75 行动序列（黑屏后修订版）

0. **重启后第一件事（零成本）**：`ls /sys/fs/pstore; cat /sys/fs/pstore/console-ramoops*`
   → 黑屏时刻的内核日志：见 system_server/watchdog → 框架反应(a)；见 oops/BUG
   → 另查；无异常只有 avc 静默 → 更可能是(b)。
1. **顺序反转：R 先行**（无副作用、7/7）：R 轮 → 子进程 CapEff 满确认 +
   记录 R-child task 地址（status 首字段）。
2. **E5 轮**：enforce=0 确认（cat 一下即可）。
3. **C 轮立即跟**（E5 后 30s 内，同 R-child 8 分钟窗口）：`PC_OFF=0x778 +
   PSELECT_TASK=<R-child task> + PSELECT_KO` → 预期 ROOT-SEEN + hostname=glroot
   + ksu_done。permissive 暴露窗口缩到最小。
4. **框架崩溃保险**：若 E5→C 之间 termux 被 framework 重启连坐（zygote 死杀
   app，R-child 陪葬）→ 全链改从 **Shizuku/adb shell 跑**（adbd 原生进程，
   活过 system_server 死亡；uid 同为 2000，配方不变，preload 部署到
   /data/local/tmp）。Shizuku 本来就是现场前置条件，零额外成本。
5. 判据汇总：`/proc/<R-child>/status` Uid: 0 0 0 + root_alive.txt + ksu_done.txt
   + hostname=glroot + pstore。
