# Fresh-Eyes 复核报告 — matisse GhostLock (2026-08-14 21:0x)

> 新模型视角复核。只读分析，未动手机、未跑测试。所有结论附一手证据。
> 本文档与 fresh_eyes_brief 配套：brief 是交接入口，本文是复核结果。

## 一、四大结论

### 1. 墙是真的，且比记录里更硬——"R8 实证过写入"是幻影
- 全库 90+ 份日志 grep：唯一出现 `bootid_changed` 的是 mt16 的 7 行，**全部 =0**。
  没有任何一次日志显示 boot_id 变过。
- R8 自己日志（logs/R8_test2/3.txt）结尾明确写着：
  `direct-w64[0] child=32599 status=0xc00` + `reason=primitive-miss`
  R8_test4 在 `direct-w64[0] target=...` 一行戛然而止，无验证结果。
- → AI_ARCHIVE_2026-07-18 §十六 的"R8 的 direct-w64 就是它写的 boot_id"是当时的乐观误读，
  被 R8 自己的日志证伪。墙结论自洽：**从未有任何写入落地，任何版本**。

### 2. mt17 的 shift 8-15 维度结构性无效（代码自己的数学说了算）
- fops.c:265-294 放置逻辑：`global_word = shift + waiter_word`，
  窗口 = pselect6 的 in/out/ex 三组 fd_set = 3 × words_per_set(5) = **15 words**。
  放不进窗口（global_word ≥ 15）就只是打警告、字段保留栈上旧值。
- mt16 日志实测：shift=5 起 w10 出窗；shift=6 w9(deadline) 出窗；shift=7 w8(prio) 出窗；
  **shift≥8 时 w7(lock) 都出窗** → 假 waiter 的 lock 指针不可控 → chain walk [3] 必挂。
- 结论：**mt17 (shift 8-15) 不用跑**。之前把它当"未试维度"是误读——它连最基础字段都摆不进去。
- 顺带：get_pselect_shift 只接受 v∈[0,20]，且 `global_word < 0` 直接拒绝 → 代码结构上
  无法表达"waiter 在窗口之前"（负 shift），见下文"真·未试维度"。

### 3. 两个误导性线索被证伪（省掉两条岔路）
- **rbtree "MTK Case 3b 无条件写 parent->rb_left" 不成立**：
  从 matisse_kernel_src.tar.gz 提取 lib/rbtree.c，与上游逐字节相同（diff 为空）。
  v30 源码注释的说法无事实依据。
- **rtmutex "matisse 定制" 基本不成立**：matisse(5.10.81) vs android12-5.10 common 的
  rtmutex.c 差异只有 16 行（trace_android_vh hook 3 处 + deadlock handler 签名 + 注释错字）。
  chain walk / rt_mutex_dequeue / rb_erase_cached(rtmutex.c:295-300) / 调用点(1002, 1108)
  全部一致 → 之前源码级推演成立。

### 4. 真正的盲区 = 几何校准 + 地址数学（不是 shift 扫描）
- 15-word 窗口模型是原版作者按 6.x 目标校准的（waiter 栈帧位置 vs pselect 三组 fd_set
  栈位置之差 = 编译期常量）。matisse 5.10.209（MTK 补丁、不同编译器）的常量未知，
  shift 0-4 全摆好却没落地 → 要么真实偏移不在 ±15 words 窗口内，要么地址数学错。
- 所有 RVA（boot_id sysctl 数据、selinux_enforcing、init_cred、entry_task…）来自
  **5.10.81 源码**，运行内核是 **5.10.209**。此漏洞族没有独立读原语（r64 读 = 写原语的
  侧信道），写从未落地 ⇒ **读从未成立 ⇒ 全部 dmap 地址数学从未被实证**。
  若 .209 有任何一个全局符号偏移漂移，所有写都会"沉默地"落在别处——与全部观测一致。
- 另一个可疑点（顺手发现，未定论）：fops.c words[8] = `(prio_val << 32) | 3`，
  小端内存里 waiter->prio(int @+0x40) 实际读到 **3** 而不是 130，prio 值被塞进了
  +0x44 的 padding。可能是从 6.x 表移植时的字节序遗留，需对照原版表确认。

## 二、真·未试维度（修正后的行动清单）
1. **拿 build 292661 的精确内核源码**（5.10.209）：
   MiCode/Xiaomi_Kernel_OpenSource 的 matisse 分支（GitHub 被墙，走 gh-proxy 镜像）。
   用途：a) 逐一校验现用 RVA；b) 编译 futex.c/select.c 算栈帧偏移常量 →
   把 shift 从"盲扫"变成"一个确定值"；c) 确认 .209 无 MTK 的 rtmutex/rbtree 改动。
2. **窗口加宽（代码可行且是真新维度）**：NFDS 320→640。
   注意上限：core_sys_select 的 stack_fds=256B，3×sets ≤256B 才走栈；
   nfds=640 → 3×10 words=240B 仍走栈（窗口 15→30 words，shift 0-19）；
   nfds=704+ 就 kmalloc 出栈 → 覆盖前提崩坏，不能超过 640。
3. **支持负 shift**：放宽 get_pselect_shift 的 v≥0 限制 + pselect_put_global_word 的
   `global_word<0` 拒绝逻辑，允许 waiter 从窗口下方进入（映射到 in 组之前的那段栈）。
4. **查 prio 字节序**（见上），对照 v30 原版表决定 words[8] 是否应写 prio 在低 32 位。
5. **非漏洞路线并行查**：
   - 官方解锁：开发者选项→设备解锁状态（locked≠不可解锁，Xiaomi 账号绑定+等待期）
   - mtkclient/MT6983：搜索未确认支持；参考同芯片 OnePlus Nord 3 (Dimensity 9000)
     root 指南（github.com/danielrosehill/One-Plus-Nord-3-Root-Guide）
   - 5.10.209 上其他漏洞面（nf_tables/io_uring 已修；MTK 私有驱动未查尽）

## 三、结论
之前卡住不是运气问题，是两个结构性问题：**几何常量从未校准**（拿 6.x 的窗口模型
扫 5.10 的栈）+ **地址数学从未实证**（5.10.81 的 RVA 用在 5.10.209 上）。
这两个都要精确源码才能解开，而不是更多的 shift 扫描。
