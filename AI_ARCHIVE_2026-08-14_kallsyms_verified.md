# 里程碑：真机内核 kallsyms 全量提取 + RVA 实证 (2026-08-14 21:3x)

## 一句话
从 `_research/kernel_edata.Image`（真机 5.10.209-android12-9-00019-g4ea09a298bb4-ab12292661
内核镜像，PE+ARMd 格式）提取出 **142102 个符号**（CONFIG_KALLSYMS_ALL=y，数据符号全在），
逐项核对了项目的 RVA 表。**地址数学基本被证实正确**——"写不落地"的锅不是地址公式。

## 提取方法（可复现）
- 镜像跳过 0x40 头；kallsyms_relative_base=0xffffffc008000000 @ 文件偏移 0x1e38ea8
- 名字格式 = **Android 移植的 6.x 格式**：[len][类型字符][压缩名]，len 含类型字符
- names_end=markers_end-1（1 字节填充）；names_start 由"最后一组 22 符号 + 全量 marker 校验"穷举
- 脚本：_research/_extract/kall6.py；符号表：_research/_extract/kallsyms.txt（addr type name）

## RVA 核对结果（项目值 vs 真机符号）
| 项目 RVA | 真机符号 | 结果 |
|---|---|---|
| 0x27b0ae0 INIT_CRED | init_cred | ✅ 精确匹配 |
| 0x27913a0 nfulnl_logger | nfulnl_logger | ✅ 精确匹配 |
| 0x27562f8 ENTRY_TASK | __entry_task | ✅ 精确匹配 |
| 0x278a558 PER_CPU_OFFSET | __per_cpu_offset | ✅ 精确匹配 |
| 0x279bec0 INIT_TASK | init_task | ✅ 精确匹配 |
| 0x28e76d8 ASHMEM_MISC | ashmem_misc | ✅ 精确匹配 |
| 0x22acf58 (ashmem_fops) | ashmem_fops | ✅ 精确匹配 |
| 0x2a60bb5 sysctl_bootid | sysctl_bootid | ✅ 精确匹配 |
| 0x28a77d0 boot_id 数据 | random_table@0x28a76c8 之后 8 字节 | ✅ 位置吻合 |
| 0x2a41b99 SELINUX_ENFORCING | **selinux_state@0x2a41b98，enforcing=state+0** | ❌ **差 1 字节** |

## 新发现
1. **selinux_enforcing 差 1 字节**：项目写的是 state+1（checkreqprot 字段）。
   真目标是 `selinux_state.enforcing` @ 0x2a41b98（bool @ +0）。
   → mt10 "selinux-zero" 即使写落地也会打错字段。
2. **39-bit VA 确认**（pstore："4k pages, 39-bit VAs"）→ P0_PAGE_OFFSET=0xffffff8000000000 正确。
   **PHYS_OFFSET=0x40000000**（pstore）→ 线性映射公式 dmap=0xffffff8000000000+(phys-0x40000000)
   （R8 ks_bruteforce 找到的 mm_struct dmap 地址与该公式自洽）。
3. **唯一残余未知 = Δ = KIMAGE_PHYS - PHYS_OFFSET**：dmap 公式 dmap=P0_PAGE_OFFSET+RVA
   成立的前提是内核镜像物理加载地址 == 0x40000000。若内核加载在 0x40080000 等偏移，
   全部 dmap 目标整体错 Δ → 写"沉默地"落空 —— 与所有观测一致。
   **Δ 尚未确定**（需真机 ROM boot.img 的 kernel_addr 字段，或 MTK lk 源码）。
4. v38 时代崩溃（pstore 2026-07-21）根因：walk 读到被清零的悬垂 waiter（x27=0,
   NULL deref, pc=rt_mutex_adjust_prio_chain+0x188）——证明 walk 确实会跟随悬垂指针进入
   已释放栈内存（原语可达性实证），但那次覆盖未成功。

## 几何校准用函数 RVA（真机）
- rt_mutex_adjust_prio_chain = 0x1eae38（oops 交叉验证 ✅）
- futex_wait_requeue_pi = 0x294d68, futex_lock_pi = 0x2935e8, futex_requeue = 0x2911ac
- core_sys_select = 0x56e2d4, rt_mutex_init_waiter = 0x1eca94, rt_mutex_slowlock = 0x1a0a938
- 结构字段（walk 反汇编实证）：pi_blocked_on@0x898, pi_waiters@0x880/0x888, task->prio@0x84,
  dl.deadline@0x360, waiter: lock@0x38/prio@0x40/deadline@0x48（10-word 布局确认）

## 下一步（按价值排序）
1. **确定 Δ**：找真机 ROM 的 boot.img（kernel_addr 字段）或 MTK 加载地址；
   若 Δ≠0 → 修正所有 dmap 目标 = 现目标+Δ → 可能就是突破本身。
2. **几何校准**：反汇编 futex_wait_requeue_pi / futex_lock_pi（帧内 rt_waiter 偏移）
   + core_sys_select（stack_fds 偏移）→ 算出 overlay 需要的精确 shift（替代盲扫）。
3. 修 selinux 目标为 0x2a41b98。
4. mt17 不跑（placement 结构性无效，见 fresh_eyes_review）。

## 追加：决定 = mt18 oracle 判别实验 (2026-08-14 21:05)
- **决策**：下一步跑 `scripts/test_mt18_oracle.sh`（零编译：mt17 二进制 + PSELECT_TREE_PC=ffffffb0fffffff8 未映射地址 + ONE_SHOT）。
- 判别逻辑：未映射 tree_pc → 若 walk 到达 [7] 且 rb_erase 读写该地址 → 内核 oops/重启（阳性=原语端到端可行，剩 Δ+写形状）；
  若没崩 → walk 在 [7] 前退出（怀疑检查 C/D：真实 requeue 任务的 pi_waiters 为空/top_waiter 不匹配）→ 转攻触发。
- 已知：overlay 命中(假 waiter 被读到) + [7] 执行 双条件同时成立才崩；mt16 的"写不落地"无法区分是哪一环。
- 备注：0xffffffb100000000 超出 12GB RAM 线性映射（x19 实证设备有 ~10.9GB phys 任务对象 → 12GB 版本）。
- 几何部分数据：futex_wait_requeue_pi rt_waiter@sp+0x70（零初始化 0x70..0xe0）；core_sys_select stack_fds@sp+0x50。
  两者均 shrink-wrap 共享调用者帧；完整 D 需 futex/pselect syscall 路径帧深（待算）。
- Δ (KIMAGE_PHYS-0x40000000) 仍未定：设备侧全封、boot v4 无 kernel_addr、web 无决定性信息。若 oracle 阳性，
  Δ 可改为"扫 tree_pc=候选目标±Δ 直到 boot_id 变化"来实测（写一旦能落地，Δ 就可扫出来）。

## 追加：mt18 oracle 卡死根因调查 (2026-08-14 21:20)
- 现象：oracle 启动后卡在 "setup KernelSnitch..." 15+ 分钟，进程存活、手机健康、boot_id 未变、logcat 无 OOM/LMK/panic。
- 排查过程（全部代码级验证）：
  1. find_collisions 非磨蹭：futex_hash_table_size=256×16=4096, total_futexes=64K → 最坏 ~20s（不是最初估的 27min）
  2. futex_init 是空操作；SYSCHK 失败只打印不中断
  3. clone_child 子进程是 pause() 循环（可 SIGKILL 收割）
  4. clone_leak_child = fork → find_collisions → exit，理论上秒级返回
  5. 卡点窗口 = kernelsnitch_setup(64GB mmap) → 68 克隆 → memfd → 271 杀子 → waitpid(child_leak)
- 结论：用户态全部有界 → 大概率**内核侧卡死**（futex 4096 线程堆叠桶的锁竞争 / mmap_lock 竞争 / D 状态），环境相关。
- 教训：本 boot 内存状态差（mt16 后 + am kill-all + 543 fork），ks 阶段不可靠。
- 计划：a) 重启 Shizuku 清理卡死进程；b) 给 exploit 加阶段级细粒度打印+看门狗（mt18-diag）定位精确卡点；c) 建议重启手机拿干净环境后重跑。

## ★★ 决定性结论：oracle 阴性，写原语端到端不成立 (2026-08-14 21:45)
- 干净重启后重跑（logs/mt18_diag3_run.out，boot_id=99c5f41e…）：FOPS 路线全流程跑通，
  ks 一次通过（重试未用），deep-chain 触发 calls=1（与 mt16 一致），fd_set 携带
  **未映射 tree_pc=ffffffb0fffffff8**，ONE_SHOT pselect 完成，**内核未崩溃**。
- 推理：若 walk 到达 [7] 且 rb_erase 以该 tree_pc 执行，Case 1 会读 parent->rb_left
  （0xffffffb100000000，未映射）→ data abort → oops/重启。没崩 ⇒ **[7] 从未以我们的
  假节点执行**。
- 结论（首次明确回答"写为什么不落地"）：**chain walk 在到达 rb_erase 之前就退出了**。
  不是地址数学（Δ 只在 [7] 之后才相关——修 Δ 也不会让写入落地）；剩两个嫌疑：
  a) 几何：pselect fd_set 从未落到悬垂 waiter 的栈内存（跨线程栈回收不成立/偏移不对）
  b) 检查 C/D：真实 requeue 任务的 pi_waiters 为空或 top_waiter 不匹配（walk 提前退出）
- 支持 (a) 的证据：Jul 21 崩溃证明 walk 会跟随悬垂指针进已释放栈（读垃圾 lock 崩），
  但 mt 系列的 overlay 从未成功过；fd_set 帧偏移（waiter@sp+0x70 vs fdset@sp+0x50）
  与完整 syscall 路径帧深的关系未算完。
- 下一步（纯本地分析）：用真机 RVA 反汇编 futex_wait_requeue_pi + core_sys_select +
  两条 syscall 路径的完整帧，算出 overlay 几何是否可行（当前 15-word 模型内），
  以及检查 C/D 在真实任务上的可满足条件。

## ★★★ 突破性发现：FOPS 路线结构性无 UAF；SLIDE 路线才是真触发 (2026-08-14 22:0x)
- 源码审计：main.c run_exploit 的 FOPS 路线（mt1-17 + oracle 全用）只有 FUTEX_LOCK_PI/UNLOCK_PI，
  **没有 requeue 操作** → 不会产生 CVE-2026-43499 的悬垂 pi_blocked_on → chain walk 处理的是
  真实链（真实 waiter/真实锁），fd_set 里的假 waiter 永远不会被读 → **写入结构性不可能发生**。
  oracle 阴性完全解释：未映射 tree_pc 从未被解引用（没有悬垂指针指向 fd_set）。
- slide.c 才是真触发：slide_waiter_thread 做 FUTEX_WAIT_REQUEUE_PI（制造悬垂 rt_waiter）+
  CMP_REQUEUE_PI（main 线程）+ **同线程** slide_pselect_stack_copy() overlay（原版 PoC 设计）。
- 但 main.c:528 只调 slide_leak_kernel_base()（硬编码 slide=0，从不调 slide_child_leak_stext 真触发）。
  mt1-4 曾尝试 slide 路线（13-word 布局）崩 3 次后放弃 → 转向 FOPS 死路。
- 结论：**项目在 mt5 起就一直在测一条从设计上无法触发的路线**；真触发（slide 路线）从未用
  10-word 布局 + shift 扫描 + 真机偏移的组合测试过。
- 下一步 mt19：把 slide_child_leak_stext() 用 env 开关接入 run_exploit，先跑 oracle
  （tree_pc=未映射）——若同线程 overlay + walk 到达 [7] → 内核崩溃 = 原语在 matisse 端到端成立！

## ★★★★ CVE 官方分析确认 + ks 阶段崩溃事件 (2026-08-14 22:25)
- 来源: guysrd.github.io/rtmutex ("futex: remove_waiter stack uaf", 2026-06-13) + dnlid/CVE-2026-43499 README
- **修复状态确认**: fix commit 3bfdc63936dd (2026-04, Keenan Dong/Thomas Gleixner) "rtmutex: Use
  waiter::task instead of current in remove_waiter()"。**只回移 6.1.175/6.6.140/6.12.86/6.18.27;
  Android13 5.10 和 5.15 未修复 → 我们的 5.10.209 有 UAF ✓✓**
- **触发机制确认**: 三线程 + 双 PI futex + 死锁环 → task_blocks_on_rt_mutex 返回 -EDEADLK →
  remove_waiter 在 requeuer 上下文执行 → waiter 的 pi_blocked_on 悬垂到弹出栈帧。
  之后任意 PI chain walk 经 task_blocked_on_lock 解引用悬垂 pi_blocked_on->lock。
- **栈覆盖**: "the slot's bytes are immediately reusable by the task's next syscall" —— 同线程
  下一 syscall 复用 slot（正是 slide 路线同线程 overlay 设计）。
- 事件: mt19 sweep shift0 在 ks 阶段崩溃重启（leak 子进程退出/回收时, 4096 futex 线程+64GB
  映射拆除）→ 与 mt3/mt4 "slide 崩溃" 同类，非 oracle 阳性；ks 阶段脆弱性（4-5 次偶发 1 次）。
- 结论: 路线正确（SLIDE 真触发 + EDEADLK + 同线程 overlay）、UAF 存在、waiter sched 可成功
  （mt19b attempt=0 ret=0）。剩余: 几何 shift 校准（0-5 扫描被 ks 崩溃打断, 待重试）。

## ★★★★★ 突破：v37 EDEADLK 路线 oracle 崩溃 = walk 到达 [7] (2026-08-14 22:5x)
- 事件：trigger_oracle（v37 trigger_stamp 变体，buf[0]=未映射 0xffffffb0fffffff8）
  运行 → 手机重启。
- 对照：v39（同触发，buf[0]=OFF_DMAP 映射地址）不崩（"phone alive"）。唯一差异 =
  buf[0] 映射 vs 未映射。⇒ walk 在两条里都到达 [7] 的 rb_erase（v39 静默写 OFF，
  本次解引用未映射 parent → oops）。
- **旧结论 "v39 walk likely exited early" 是错的** —— walk 没提前退出，写原语在 v37
  EDEADLK 路线上端到端成立！（v39 用 boot_id 验证但目标是 ashmem fops → 误判）
- v37 路线要点（CVE-2026-43499_ref/trigger_stamp.c, 139 行, 无 ks 无喷页, 秒级）：
  FWRQ→EDEADLK/超时(栈释放) → 同线程 setsockopt(512B) 立即 stamp 释放槽 →
  FLPI(cycle_futex) 触发 walk → walk 读 stamp（v37 NULL-task 崩溃已证明位置正确）。
- 下一步：stamp buf[0] = boot_id-8 (0xffffff80028a77c8)，buf[7]lock = 有效假锁
  （需内核内存, 后续接喷页）→ boot_id 变化 = 写原语可验证落地 → 接完整提权链。

## ★★★★ v37 路线判别结果：walk 波动性到达 [5]/[7]，C/D 检查是波动源 (2026-08-15 00:1x)
- trigger_bootid（v37 触发 + buf[0]=boot_id-8 + buf[7]=0xBEEF）：FCRQ→EDEADLK(35) ✓,
  FWRQ→超时(110) ✓, FLPI probe 返回 ✓, **boot_id 未变、未崩** (run_rc=0)。
- 对照 trigger_oracle（同触发, buf[0]=未映射）→ 崩（重启）。
- 推论：walk 通过 C/D 与否是 run-to-run 波动的（pi_waiters/top_waiter 时机）。
  - 通过时：走到 [5]（0xBEEF 假锁→崩）或 [7]（oracle 崩）
  - 未通过：C/D 提前退（bootid 未变）
- 歧义未决：oracle 崩在 [5] 还是 [7]（0xBEEF 是 user VA, EL1 访问必崩）。
- 修复方向（mt20）：v37 触发 + mt19 喷页融合 —— stamp buf[7]=fake_lock(喷页, wait_lock=0
  → [5] 过) + buf[0]=目标 + **v37 顺序（FWRQ 后立即 stamp, 无 stray-walk 窗口）** + FLPI
  确定性触发。C/D 波动靠链拓扑工程化（原版 PoC 做法）。

## ★★★★★ mt20 构建完成：v37 立即 stamp + SLIDE 假锁 (2026-08-15 00:4x, 未测试)
- preload_mt20.so SHA=fb69f92c404ac9b8725baa718fb4384f93bab349875212e24affc5403388e49a
- 改动 (slide.c): 新增 slide_stamp_fake_waiter()（setsockopt MCAST_JOIN_SOURCE_GROUP
  512B → v37 校准的释放槽偏移）; slide_waiter_thread 用 stamp 替换 pselect overlay,
  stamp 后置 consume_go=1 触发 consumer 的 sched walk。
- stamp 假 waiter (10-word): buf[0]=PSELECT_TREE_PC(env, 默认 SLIDE_LOGGERS_0_1),
  buf[6]=SLIDE_INIT_TASK, buf[7]=fake_lock(SLIDE 喷页: wait_lock=0→[5]过,
  owner=0→[6]过+[9]链尾干净退出), buf[8]=prio。
- 推理链: walk 读 stamp → [3] next_lock==waiter->lock 自证 → [4] lock=fake_lock →
  [5] trylock(wait_lock=0)✓ → [6] owner(0)≠top_task✓ → [7] rb_erase 写 buf[0]
  （boot_id-8 → 写 0 到 boot_id+0 → UUID 变化可验证）→ [9] owner=0 干净返回。
- 测试: scripts/test_mt20_bootid.sh (3 次尝试 × 140s, boot_id 每轮验证)。
  PSELECT_TREE_PC=ffffff80028a77c8 (boot_id-8); oracle 变体用 ffffffb0fffffff8。
- 剩余风险: C/D 检查波动（v37 时有时过）; ks 阶段崩溃（已降到 2048线程/32GB）。

## ★★★★★ mt21 三标记判别结果：exploit 环境下 walk 未读 stamp (2026-08-15 01:3x)
- mt21 (v37 拓扑移植: cycle/futex1/futex2 + FCRQ→EDEADLK + stamp + FLPI probe):
  3 个判别标记全部阴性（FLPI ret=0 干净返回, 无崩溃, boot_id 未变）:
  1. tree_pc=未映射 → 不崩 → [7] 未达
  2. lock=未映射 → 不崩 → [4]/[5] 未达
  3. lock=0 + task=NULL (July v37 NULL-crash 同款) → 不崩 → walk 未读 stamp
- 与 July v37 standalone 的矛盾: standalone 的 NULL-crash 证明 walk 读 stamp;
  移植进 exploit 后同一机制不复现。
- 纸上推演所有检查 ([3]-A/B/C/D/E, [5], [6]) 都应通过 → 实际却没到 [4]。
  矛盾点: FLPI ret=0 (阻塞~500ms 后获取 → walk 应在阻塞期运行) 但没读 stamp。
- 待解: (a) 悬垂 pi_blocked_on 在本拓扑是否真存在 (UAF 时机条件敏感);
  (b) FLPI 是否真阻塞 (需时间戳验证); (c) exploit 内存环境破坏 stamp 落地。
- 备选路径: 回到 standalone trigger_stamp 验证环境差异; 或换触发拓扑。

## 🎉🎉🎉 历史性突破：mt22 写原语实证成功 (2026-08-15 02:2x)
- preload_mt22.so SHA=a46f3e3353d37065b4d686f0d91dec6a9ea73df4427fc9595b7b48ff4c2fbc0b
- 关键修复（源自 JoinChang/ghostlock-oneplus 源码对比）:
  1. **consumer 在 sched 后补一发 futex_lock_pi(f_pi_target, 50ms) 触发**
     （OnePlus 上 sched 结构不兼容→futex 回退→walk; matisse 上 sched 成功但
     walk 不执行 → futex 触发才是真正驱动 walk 的机制!）
  2. pselect overlay 恢复 (10-word 表) + 8 轮重试 + boot_id 验证
- 结果: "★★★ WRITE PRIMITIVE CONFIRMED attempt=1 ★★★"
  futex trigger ret=-1 errno=110 (超时阻塞 50ms → walk 期间执行) →
  pselect calls=1 → boot_id 字节被改写 (bad leaked pointer=774813fe92cb2f1f,
  非原值) → CONFIRMED。写入后系统重启 (rb_erase 写内核数据区的副作用)。
- **写原语在 matisse 5.10.209 上真实成立!** 剩余: 写形状校准 (值/偏移,
  当前写进了 boot_id 但值非预期 0)、写入后内核稳定性 (避免副作用重启)。
- 下一步: 精确目标 (selinux_state.enforcing 0x2a41b98 / init_cred) + 形状控制。

## ★★★★★★ 写原语"活着"——boot_id 被持续自发改写 (2026-08-15 00:05)
- 用户纠正: 没有重启 (harness 会话未断 = 铁证); boot_id 变化 = 写入原语就地改写数据。
- 3 次读取 4 秒内 3 个不同值 (d807d3a4→b71f204b→a564614c) = **持续自发写入**!
- mt22 run 进程已退出 (ps 无残留), 但写入继续 → **内核自身的 PI 链活动驱动 walk 重放**
  (悬垂 pi_blocked_on + overlay 数据残留在已释放 waiter 栈 → 系统任何 futex/PI 事件
  触发 walk → [7] 改写 boot_id)。
- 内核全程稳定 (MemFree 1.9GB, 无崩溃) → 写原语真实成立且非破坏性 (对无害目标)。
- 写形状未受控 (boot_id 被写垃圾值 — rb_erase 重平衡路径), 目标也未对准。
- mt23 方向: 形状控制 (JoinChang "write-1": fake_right 值的低字节编码目标字节)
  + 目标对准 selinux_state.enforcing (0x2a41b98) / init_cred。

## mt23 形状校准代码完成 (2026-08-15 00:10) — 测试待重启后
- preload_mt23.so SHA=8e95cf8526ceb1686b85c04dcf63b802ebce17668ded3dbd9d1291f62d870219
- 改动: fd_set 表 word1(tree_right) 支持 PSELECT_TREE_RIGHT env (Case 1 写入值);
  PSELECT_PROBE=1 → word2-5 填 0xCAFE.. 标记 (几何校准探针);
  测试脚本 scripts/test_mt23.sh (retry=4, boot_id 验证)。
- 重要教训 (用户报告): 自发写入会渐进腐蚀内核 (开应用 = 密集 futex → 持续触发
  walk → 失控形状写垃圾) → 手机无法开应用 → **必须重启清理**。重启后测试。
- 自发现象本身是原语的铁证; 但形状必须受控 (mt23 目标: 干净 0 写入 boot_id,
  探针回读校准几何偏移)。

## 📌 会话结束交接 (2026-08-15 00:4x, 用户睡觉)
### 核心成果
1. **写原语在 matisse 5.10.209 上端到端成立** (mt22 attempt 1 CONFIRMED):
   boot_id 被改写 + 持续自发写入 = 铁证。CVE-2026-43499 悬垂链 + overlay + walk [7] rb_erase 全链路通。
2. 关键修复链: 13-word→10-word 表; FOPS 路线无 UAF(结构性死路); SLIDE 路线(v37 EDEADLK 触发)
   + **futex_lock_pi 触发**(sched 触发不驱动 walk — JoinChang 源码对比得出);
   + 重试循环 + boot_id 验证。
3. 真机工具: kallsyms 全量提取(142102 符号, RVA 全验证), 反汇编流水线, pstore 分析。

### 遗留问题 (下一个会话/模型的主线)
- **可靠性低**: 写中率 ~10-25%/attempt (mt22 一次中, 之后 16 次不中) — 触发时序状态相关, 需调优
- **形状未受控**: mt22 写入值为垃圾(非 0 非目标) — rb_erase 路径/几何需校准
- **自发现象双刃剑**: 悬垂链存活时系统任何 futex 操作触发 walk → 持续写(可腐蚀内核 → 需重启);
  mt23c/mt24 (非零 tree_right) 反而降低触发率
- 提权链未接: 目标 selinux_state.enforcing (0x2a41b98) / init_cred (0x27b0ae0)

### 关键技术事实 (勿重推)
- 5.10 waiter = 10-word 扁平 (task@0x30 lock@0x38 prio@0x40 deadline@0x48)
- walk 检查: [3] next_lock==waiter->lock (自证), C/D (pi_waiters/top_waiter — 波动源),
  [5] trylock(wait_lock), [6] lock==orig_lock||owner==top_task, [7] rb_erase
- SLIDE 假锁: wait_lock=0, owner=0 → [5][6] 过 + [9] 链尾干净退出
- sched 路径 walk 调用: orig_lock=NULL, orig_waiter=NULL (rt_mutex_adjust_pi)
- 触发: FCRQ→EDEADLK(35) + FWRQ→超时(110) + futex_lock_pi(f_pi_target, 50ms) 触发 walk
- JoinChang/ghostlock-oneplus 源码: 项目根 ghostlock_src/ (write-1 模式参考)
- 当前手机: 稳定, boot_id=97ae8367, 无自发写入 (可安全继续测试)

### 二进制/脚本
- preload_mt22.so (CONFIRMED 版本) / preload_mt23.so (tree_right=fake_lock 默认)
- scripts/test_mt22.sh / test_mt23.sh (mt23 当前: retry=8, tree_right 默认 fake_lock)

## 🎉🎉🎉🎉 SELINUX PERMISSIVE — 写入原语关闭 SELinux (2026-08-15 08:43)
- mt26: tree_pc = selinux_state.enforcing-8 (0xffffff8002a41b90) + 6 连发 futex 触发
  + 独立进程 x5 轮 → **round 4 getenforce=Permissive**!
- 机制: rb_erase 写 parent->rb_right (=parent+8=enforcing) 值 = tree_pc & ~0xff
  (低字节恒 0x00) → enforcing byte0=0 → false → Permissive。
- 新解锁权限 (Permissive 后 rish/uid 2000):
  - /proc/kallsyms 可读 (符号名可见; 地址仍被 kptr_restrict 置零)
  - dmesg 可读!
- 下一步: cred 覆写 (task->cred@0x780 = init_cred 地址 → uid 0)。
  注意: 写值 = tree_pc & ~0xff (目标页对齐), 无法写精确地址 — cred 形状需工程化。

## mt28 会话进展 (2026-08-15 下午) — Case-2 任意值写 + cred 尝试

### 已确认的事实
- **perf_find_task 泄露自身 task_struct 可用** (Enforcing 下也行, perf_event_paranoid=-1):
  task=0xffffff82xxxxxxxx, 225-249/256 票, 稳定. (mt28a)
- **写原语两种形状**:
  - 主树写 (tree_left=0, Case-1): 稳定触发, 写值 = tree_pc 派生 (mt25: 0x...7700=tree_pc&~0xff;
    mt28b/d: 0x...77c8=tree_pc), 落点 = tree_pc+8. 无法写任意值.
  - Case-2 写 (tree_left≠0, rb_set_parent(tmp,successor) → ***(tree_left)=tree_right**):
    源码+反汇编确认 (0xa712a4-0xa712b8), 值=tree_right, 目标=tree_left. **但真机表现反复**.
- **RB_RED=0, RB_BLACK=1** (bit0=1=黑). rb_is_black(successor)=*(successor)&1.
  - successor 黑 → rebalance=parent → rb_erase_color 旋转 → **撤销刚写的值 + 野写** (mt28g2 的 Permission denied 污染源头)
  - successor 红 (bit0=0) → rebalance=NULL → 干净
- **崩溃点汇总** (pstore 确认):
  - rtmutex_common.h:60 = rt_mutex_top_waiter 的 BUG_ON(w->lock != lock): 悬垂槽是 waiters 树
    leftmost 时, 其 lock 字段 (word7=fake_lock) ≠ 真锁 → BUG → panic. (mt28i)
  - 写 init_cred.usage (活 refcount) → 竞争/崩溃 (mt28h 两步法 step1 崩, 即使 tree_right=0x77e0)
- **ks 阶段在 perf_find_task 之后运行会挂** (open /proc/<pid>/mem Permission denied) → **必须先备页再 perf** (mt28m 修复, 全管线通了!)
- **进程内重试毒化**: [5] trylock(fake_lock->wait_lock) 写 wait_lock=current → 后续 attempt 的 [5] 必败 → 重试必须独立进程 (mt28k)
- **LOCK_OFF+0x80 区域不能放假 cred 字段**: 那是 mm_struct 字段, ks 碰撞检测读到指针就挂 (mt28j)

### 假 cred 方案 (mt28m/n, 当前状态)
- SLIDE 页 @0x3800 假 cred: usage=0x100(红), uid..fsgid=0, caps 全开, security=@0x3900 假 blob {sid=1}
- 管线: 备页→perf→envs(tree_pc=task+0x818, tree_right=page_base+0x3800, tree_left=task+0x820)→触发
- **结果: 全管线通, 6 次尝试无 root** — Case-2 写是否触发无法确认 (boot_id 观测测试 mt28n 显示 boot_id 变了
  但值≠fake_cred — 疑似自发写入而非 Case-2)

### 待解问题
1. Case-2 写在 preload 触发下到底触发没有 (mt28g2 的重平衡污染证明 erase 跑过, mt28m 却无 root)
2. tree_left≠0 时 rt_mutex_top_waiter BUG 的规避 (让消费者 waiter 成为 leftmost?)
3. 若 Case-2 可靠: 假 cred 的 sid=1(kernel) 能否 setenforce 0 (avc: allow kernel security_t?)

### 当前手机状态
- 重启后干净, Enforcing, boot_id=019b5de3 (mt28n 后 = 17241ce4, 部分 4 字节被改)
- /data/local/tmp/preload.so = mt28n 二进制 (sha256 91de8fe3)
