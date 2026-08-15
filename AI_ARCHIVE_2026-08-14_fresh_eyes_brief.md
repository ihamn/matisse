# Fresh-Eyes 交接简报 — matisse GhostLock → KernelSU (2026-08-14 20:10)

> 给新模型的一次性简报：目标、技术、已证实的墙、所有试过并否掉的方向、
> 还没试过的维度、以及最想请你挑刺的盲区。读完这一份 + 关键源码即可开始，
> 不必翻 31 节历史归档。

---

## 0. 一句话目标
在**用户自己的** Redmi K50 Pro (matisse) 上安装 KernelSU。Bootloader **已锁**（verifiedboot=green, flash.locked=1），
所以路线 B：用 CVE-2026-43499 (GhostLock) 拿临时 root → `insmod` 官方 `android12-5.10_kernelsu.ko` (v3.2.5, 已下载 344KB) → 每重启重新执行。

## 1. 设备 / 内核事实
- Redmi K50 Pro, MTK Dimensity 9000 (MT6983), HyperOS 2.0.6.0.ULKCNXM
- 运行内核: `5.10.209-android12-9-00019-g4ea09a298bb4-ab12 292661` (非 GKI, MTK vendor 树)
- KASLR: **开启** (`CONFIG_RANDOMIZE_BASE=y`)；但 direct-map (dmap) 地址与 KASLR 无关
- 手头源码: `_research/matisse_kernel_src.tar.gz` = sekaiacg/android_kernel_xiaomi_matisse, **5.10.81**（注意：与运行内核 5.10.209 差一个次版本！）
- 关键 dmap 地址（KASLR 无关）: ASHMEM_MISC_OFF=0xffffff80028e76d8, boot_id dmap=0xffffff80028a77d0, SELINUX_ENFORCING dmap=0xffffff8002a41b99, INIT_TASK dmap=0xffffff800279bec0, nfulnl_logger dmap=0xffffff80027913a0, INIT_CRED RVA 0x27b0ae0, KIMAGE_TEXT_BASE=0xffffffc008000000, P0_PAGE_OFFSET=0xffffff8000000000, P0_PHYS_OFFSET=0x80000000
- 权限环境: rish (Shizuku) = uid 2000 shell；`/proc/kallsyms`、dmesg、drop_caches、compact_memory 全部 SELinux 拒绝；`/proc/sys/kernel/random/boot_id` 可读（写验证目标）；Shizuku 服务经常死，需用户在 App 里点重启
- 用户硬性规则: 跑测试前先告知；每次测试前后留档 (logs/ + AI_ARCHIVE)；每重启最多 2 次重测试；跑一次前先 `am kill-all` + 内存压力清 slab

## 2. 技术要点 (GhostLock / CVE-2026-43499)
- rtmutex UAF: futex PI requeue 路径 `remove_waiter` 后 `pi_blocked_on` 悬垂指向已移除的 waiter
- waiter 是**任务内核栈上**的 `rt_mutex_waiter`；pselect 的 fd_set 覆盖同一栈区 → 构造假 waiter（写原语）
- chain walk 读假 waiter → `rb_erase_cached(&waiter->tree_entry, &lock->waiters)` 用假 tree_pc/tree_right/tree_left 写入任意 dmap 地址（rb_erase 的 parent/child 重链接写）
- **5.10 的 waiter 是扁平 10 字** (task@+0x30, lock@+0x38, prio@+0x40, deadline@+0x48)；13 字是 6.x 布局（已由 rt_mutex_init_waiter 反汇编确认）
- task_struct: real_cred@0x778, cred@0x780（commit_creds 反汇编确认；早期项目里的 0x818/0x820 是错的）
- 写原语硬限制（电脑端分析 + rb_set_parent 语义）: shape=1 的写会把 value+0 也破坏，只能安全写 0 → 目标选 boot_id / selinux_enforcing 这类"写 0 有意义"的变量

## 3. 已证实的墙（最重要，别重复造轮子）
**matisse 5.10.209 上 rb_erase 的写从未落地。** 跨 17 个版本 (mt1-17) + R 系列 + v 系列 + 电脑端:
- 触发有: deep chain (3 层 PI) + OFF/selinux-8 parent → ret 36-193, calls=1（每次都能触发）
- 写不落地: 所有 shift 0-7、所有 parent（OFF=0xffffff80028e76d8 / selinux-8 / boot_id-8）、TREE_RIGHT/LEFT=0、各种组合，boot_id 与 selinux 均验证**未变**
- mt16 决定性一轮: shift 0-7 全扫, 每轮 calls=1 但 `bootid_changed=0`；warmup=0 (SKIP_WARMUP 生效)、无崩溃
- 源码级分析 (android12-5.10 common rtmutex.c): chain walk 在 rb_erase 前有多重检查 —— [3] next_lock==waiter->lock, [5] raw_spin_trylock(lock->wait_lock)（假 lock wait_lock=0 可过）, [6] lock==orig_lock || rt_mutex_owner(lock)==top_task —— 均可用假值满足；requeue 路径 [7] `rt_mutex_dequeue` → `rb_erase_cached` 必须执行；`RB_EMPTY_NODE` 门（tree_pc≠node 地址）
- 主流假设（未最终证实）: pselect fd_set 覆盖**永远没落到**被释放的 waiter 栈区（栈帧几何），或 [5] trylock 在真锁上争用失败

## 4. 已试过并否掉的方向（防止新模型重走）
| 方向 | 结果 |
|---|---|
| 2-thread 触发 vs deep chain | deep chain 才是强触发 (ret 193)；2-thread 弱 |
| 13-word 布局 | 5.10 用 10-word（反汇编证实），13-word 早期崩 |
| SIGALRM 辅助 | 崩 slab，去掉 |
| warmup 喷页 | mt15 卡 FOPS；SKIP_WARMUP (mt16+) 干净跑完 |
| 内存压力清 slab (mem_pressure.c) | 有效但不够；`am kill-all` 才恢复 mm_struct 喷页 cache |
| shift 0-7 扫描 | 全部 bootid_changed=0 |
| OFF / selinux-8 / boot_id-8 parent | 全不落地 |
| 电脑端 7 月 21 日那轮 | 同样不落地（该次崩溃 slide=0x26d2400000）|
| Firefox 链 (CVE-2026-10702, 151.0) | 内核步=同一 GhostLock 技术；无 matisse payload（演示只到安卓 16/17 GKI 6.x）；价值=投递层，内核墙不变 |
| KASLR 猜测/暴力 | 不开；kallsyms 全封；dmap 地址与 slide 无关 |
| RB_EMPTY_NODE 门、属主链检查 | 用假值都可满足（源码级推演） |

## 5. 还没试过的维度（新模型优先看这里）
1. **mt17 已构建未运行** (preload_mt17_v30tech.so, SHA256=e8a775a0e81388f79157bf7d11cfbaf7d0ead9edbf6aa8435ccb46e0cd207c5d): PSELECT_SWEEP_MAX=15（shift 0-15 全扫，之前只到 7）+ SKIP_WARMUP + boot_id 验证。v30 的 get_pselect_shift 支持到 20。**测试脚本已指向它** (scripts/test_mt15_sweep.sh 实际部署 mt17)。运行前需用户确认（规则：跑之前告知）。
2. **rbtree.c 的 MTK 定制未验证**: v30 源码注释声称 matisse 的 lib/rbtree.c 在 Case 3b **无条件写 parent->rb_left**（与上游不同）。若属实，rb_erase 的写入模型整个不同。`_research/rtmutex_src/rbtree_matisse.c` 已提取，**尚未比对确认**。⚠️ 且这是 5.10.81 的树，运行内核是 5.10.209。
3. **FUTEX_LOCK_PI / requeue 触发路径**: rtmutex.c 约 1002/1113 行另一处 chain walk 调用点（orig_waiter≠NULL）从未试过；当前 exploit 只走一条触发路径。
4. **"dmap 读"从未被单独验证**: 整条链假设 P0_PAGE_OFFSET=0xffffff8000000000 + RVA 的地址数学正确。我们从未在设备上独立证明"能通过这条路径**读到** dmap 内容"（bootid_before 是否真的等于 /proc 的 boot_id？selinux 读回值是否真的等于 getenforce？）。若地址数学整体偏移，写不落地就完美解释了——**这是最值得先排除的盲区**。
5. **官方 BL 解锁可行性从未查过**: "locked" ≠ "不可解锁"。Xiaomi/HyperOS 解锁 = 开发者选项查解锁状态 + Mi 账号绑定 + 等待期（有的设备/账号秒解）。**若可官方解锁，整个 exploit 路径作废，直接刷 KernelSU 补丁 boot.img**。需要新模型查当前 (2026-08) Xiaomi/HyperOS 解锁政策与 matisse 是否支持。
6. **mtkclient / MTK BROM 路线**: Dimensity 9000 (MT6983) 是否在 mtkclient 支持/爆破范围内（kamakiri 类 bootrom 漏洞只到旧 Helio，但值得 web 查最新进展）——可绕过锁直接读/刷 boot。
7. **5.10.81 源码 vs 5.10.209 运行内核的偏移漂移**: 反汇编验证来自哪个二进制？（`device_recovered_2026-07-21/` 里有崩溃恢复的 kernel image？kernel_edata.Image？boot_synth_v4.img？）若验证基于 5.10.81 构建，需确认 Xiaomi 是否发布 292661 的精确源码。
8. **其他 5.10/MTK 漏洞面**（用户要求"不要被漏洞局限"）: 查 5.10.209 + MT6983 上还有哪些已知可利用面（nf_tables 系已修、io_uring 已修、MTK 私有驱动、CVE-2022-20409 类 MTK 漏洞、evil-mtk 系）。
9. **shift 8-20 扫完后仍不落地 → 换触发路径/换目标变量**（如 nfulnl_logger 内容指针 RVA 0x2065d50）。

## 6. 新模型请重点挑刺的问题（我们可能有思维定势）
- 我们全程假设"写不落地 = 覆盖没到位 / 检查不过"。**有没有可能是目标地址本身就不对**（P0_PAGE_OFFSET、RVA 来自错版本）？怎么在无 root 下证明/证伪？
- pselect fd_set 覆盖 waiter 的几何假设里，我们扫的是"shift"（fd_set 在栈内的偏移）。**有没有别的不变量我们没扫**（比如任务栈是 vmalloc'd (CONFIG_VMAP_STACK) 时的地址空间差异）？
- rb_erase 写不落地，但**调用计数是真的吗**？calls=1 是数到 rb_erase 前的哪个点？（rb_erase_count 检查点在 v30 里数过）
- 整个 exploit 的"写原语"必须依赖 chain walk 走到我们的假节点。**有没有一条路是跳过 chain walk 直接改树**（比如 requeue 路径的 rt_mutex_dequeue 直接对 lock->waiters 操作）？
- MTK 调度器/锁实现是否让 rt_mutex 的 wait_lock 长期被占（[5] trylock 失败率 100% 的可能）？怎么测？

## 7. 文件地图
- 项目根: `/storage/emulated/0/Documents/matisse_backup_essentials/`
- 版本: `preload_mt*.so`（mt17 最新）；工作区 `_research/mt11_v30/` (src/main.c fops.c slide.c offset.h)
- 测试: `scripts/test_mt15_sweep.sh`（实际跑 mt17, deploy+run+boot_id 对比, nohup 到 logs/mt17_test1.txt）；rish 调用方式见归档
- 归档: `AI_ARCHIVE_2026-07-18_kernelsu_plan.md` (31 节), `AI_ARCHIVE_2026-08-14_session_summary.md`
- 源码: `_research/rtmutex_src/` (rtmutex.c android12-5.10 common, rtmutex_matisse.c 5.10.81, rbtree_matisse.c)
- KernelSU 准备: `kernelsu_prep/` (ko + apk + ksuinit)
- Firefox 链: `_research/CVE-2026-10702/`

## 8. 立即建议的下一步（按性价比排序）
1. 先跑 mt17（shift 0-15）—— 若 8-15 中任一位落地 = 突破（跑前需用户确认）
2. 同时/随后做 §5.4 的"dmap 读验证"（排除地址数学整体错误）
3. 比对 rbtree_matisse.c 的 MTK 定制（§5.2）
4. web 查 §5.5 官方解锁 + §5.6 mtkclient 最新状态 —— **可能直接绕开整条 exploit 路线**
