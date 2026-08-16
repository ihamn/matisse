# 项目完整脉络（会话叙事）— 2026-08-14 深夜 → 08-15

> 目的: 给外部评审一条完整的故事线（接手前 + 接手后），
> 让它能理解"为什么项目走到现在、每步的假设/结果/教训"。
> 接手前（mt22/25/26/28）来自档案 AI_ARCHIVE_2026-08-14_kallsyms_verified.md 与会话日志；
> 接手后（mt29-45）来自本次会话实际操作记录。

---

## 第零部分：7 月坟墓（v 系列 + R 系列，两条死路）

### 0.1 路线 1 — v 系列 (v1-v36): deep PI chain + pselect GhostLock → FOPS 覆写
- 机制: deep PI chain（block_holder→owner→waiter 三层），waiter 阻塞在 FUTEX_LOCK_PI，
  pselect_thread 在 waiter 阻塞期间跑 GhostLock 竞态 → rb_erase 写
- 结论: 死路。rb_erase 的 csel 检查 parent->rb_left==node 永远失败 → 永远写 parent+8 (name_ptr)，
  永远碰不到 parent+0x10 (fops)。v30 最强触发 ret=193 也只是写 name_ptr
- 留存资产: deep chain 稳定架构 + shape=1 框架 + 10-word 表 + canon_addr 修复

### 0.2 路线 2 — R 系列 (R1-R11): GhostLock shape=1 直写 cred
- 思路: 放弃 FOPS，用 shape=1 直接写 current->cred = init_cred
- 需要先 shape=0 读原语泄露 per-CPU delta
- 结论: 关闭。shape=0 读原语写 per-CPU offset 表 → 立即 kernel panic；
  R8_test4 首次 bruteforce 成功但 fake_task 导致 pselect 期间 panic
- 教训: 永远不要写 per-CPU 区域、永远不要用假 task（要用 init_task）

### 0.3 路线 3 — trigger_stamp (v37/v38): EDEADLK UAF + 栈喷
- 原始 trigger.c 的 EDEADLK + stack UAF 路线（不依赖 pselect）
- v37/v38: NULL task 验证证明 stamp 落点正确（崩 = 读到了）
- 这是后来 8-14 真触发路线的种子（v37 EDEADLK 拓扑）

### 0.4 7 月教训（接手时带的包袱）
- MTK slab 脆弱: 每重启最多 2 次测试，第 3 次大概率崩
- Termux 弹退: 源码禁止 /tmp、测试前后留档
- deploy.sh 哈希铁律: Shizuku cp 曾写全零文件
- 偏移必须反汇编验证: 0x820（错）vs 0x780（对）的教训源头
- 7-18 项目搁置（当时判定 FOPS 死路 + R 关闭，无路可走）

### 0.5 为什么这段重要
外部评审需要理解: 8-14 的"破案"（FOPS 结构性无 UAF）不是凭空来的，
是 7 月两条死路（v/R）撞了无数遍后的最终归因。
同样，"写原语成立"（mt22）是在 7 月"写不落地"的所有教训之上才达成的。

## 第一部分：接手前（8-14 深夜 → 8-15 早晨，对面会话）

### 1.1 8-14 21:0x-21:45 — 写原语"端到端不成立"的误判期
- **mt18 oracle 判别**: 未映射 tree_pc 不崩 → 当时结论"walk 在到达 rb_erase 前退出，写原语不成立"
- **教训**: 这个结论后来被推翻（见 1.3），但当时它驱动了转向

### 1.2 8-14 22:0x — 决定性破案: FOPS 路线结构性无 UAF
- **源码审计**: FOPS 路线只有 FUTEX_LOCK_PI/UNLOCK_PI，没有 requeue
  → 不会产生悬垂 pi_blocked_on → fd_set 假 waiter 永远不会被读 → 写入结构性不可能
- **结论**: mt1-17 全在测一条设计上无法触发的路线（白测）
- **真触发**: SLIDE 路线（v37 EDEADLK + 同线程 overlay）

### 1.3 8-14 22:5x — v37 EDEADLK 路线 oracle 崩溃 = walk 到达 [7]
- trigger_oracle（未映射 buf[0]）→ 手机重启；对照 v39（映射）不崩
- **写原语端到端成立!**（当时重要转折）

### 1.4 8-15 00:1x-02:2x — 触发可靠性攻关
- v37 路线: walk 波动性到达 [5]/[7]，C/D 检查（pi_waiters/top_waiter）是波动源
- **mt20**: v37 立即 stamp + SLIDE 假锁
- **mt21**: 三标记判别 → exploit 环境下 walk 未读 stamp（矛盾待解）
- **mt22 (02:2x) ★★★ 写原语实证成功**: boot_id 被改写 + 自发持续写
  - 关键修复: consumer 在 sched 后补发 futex_lock_pi(f_pi_target, 50ms) 触发
  - 对比 JoinChang/ghostlock-oneplus 源码得出（OnePlus sched 不兼容→futex 回退→walk）
- **自发现象**: 悬垂链存活时，系统任何 futex 触发 walk → boot_id 持续被改（= 原语铁证，也是风险）

### 1.5 8-15 00:4x — 会话交接（用户睡觉）
- 核心成果: 写原语成立、关键修复链（10-word 表 + SLIDE 路线 + futex 触发）
- 遗留: 写中率 ~10-25%、形状未受控、自发写需重启清理

### 1.6 8-15 08:43 — ★★★★ mt26 SELINUX PERMISSIVE（早晨成功）
- **mt25 (08:26)**: 写 boot_id 成功（TREE_PC=boot_id-8），boot_id 从干净 97ae8367 → 00778a02-80ff-ffff...
- **mt26 (08:29)**: 接力写 enforcing（TREE_PC=enforcing-8），round4 Permissive
  - 机制: 写 enforcing byte0=0 → Permissive
  - **关键**: mt25 激活悬垂链 → mt26 接力（间隔 3 分钟）
- **新权限**: /proc/kallsyms 符号可见、dmesg 可读（kptr_restrict 仍掩地址）

### 1.7 8-15 上午-下午 — mt28 系列（Case-2 任意值写 + cred 尝试）
- perf_find_task 泄露自身 task_struct（225-249/256 票，稳定）
- Case-2 写（tree_left≠0 → *(tree_left)=tree_right）: 源码确认，但真机表现反复
- 假 cred 方案（喷页 @0x3800）: 6 次尝试无 root
- 踩坑: ks 顺序（先备页再 perf）、进程内重试毒化、LOCK_OFF+0x80 雷区
- 遗留: Case-2 是否触发未定、假 cred 为何无 root 未定

---

## 第二部分：接手后（8-15 下午 → 晚上，本会话）

### 2.1 交接核验（14:0x-14:3x）
- 读交接文档 + 全部档案，独立核验发现两个盲点:
  1. "成功率 30-50%" 虚高（实测 10-25%）
  2. 早晨 mt26 成功时 boot_id 已污染（00778a02-... = mt25 写的，非干净状态）
- 固化 4 个 skill（后来扩展到 10 个）

### 2.2 两段式复现 PERMISSIVE（15:04-15:16）★
- mt25x（写 boot_id）round1 WRITE CONFIRMED
- mt26x（写 enforcing）round2 PERMISSIVE
- **亲手复现了早晨配方** — 写原语可靠
- Δ=0 证明: boot_id + enforcing 双目标命中 ⇒ 地址公式无偏移
- 权限验证: Permissive ≠ root（uid 2000, cap 全 0, 不能 insmod）

### 2.3 cred 提权攻坚（15:2x-16:5x）
- **TASK_CRED_OFF 破案**: 0x820 → 0x780（commit_creds 反汇编铁证: ldr x19,[x20,#0x780]）
- mt28o: Case-2 写触发确认（tree_left=boot_id → 崩溃 = 写发生了）
- mt29: 修正偏移后写假 cred → attempt3 崩
- mt30: 写 init_cred 指针（ghostlock W2 经验）→ 不崩但 futex trigger 全 110

### 2.4 写 cred 指针必崩的源码级破案（17:0x-18:0x）★★★
- kernel/cred.c __put_cred: BUG_ON(usage!=0) + BUG_ON(cred==current->cred)
- **写 task->cred = 任意 cred（init_cred 或假 cred）→ 进程退出时 put_cred → BUG → 必崩**
- 6 次崩溃（mt32-36）后停止盲试，转研究

### 2.5 路线 C 探索（18:0x-19:5x）★
- 思路: 不写 cred 指针，写 cred 内容（uid 字段）
- cred 偏移反汇编: getuid 读 cred+0x4（real uid）、geteuid 读 +0x14（euid）
- mt38/39: setresuid 采样（x19=cred 全程可见）→ cred_cand 稳定识别（26-35 票）
- mt41: OBS_ONLY 纯观察 → cred_cand 每进程独有（符合 cred 特征，但非唯一）
- mt44: TREE_PC 主树写 cred+0x4=0 → futex trigger 110（写不落地）

### 2.6 外部评审介入（8-15 深夜 → 8-16）
- 推仓库到 Gitee，外部独立 AI 评审
- **外部评审三新发现**:
  1. 写入值 = tree_right/tree_left 本身（不是 tree_pc 派生）— 推翻我们"Case-1 写不了任意值"
  2. mt26 的 Permissive 就是"单条干净零写"原语实证（w1=w2=0 + RED）
  3. mt44 差一行代码: uid@+0x4 应轮扫 0x14/0x4/0x1c/0x24
- 外部喊停"负 shift 扫描"（slide.c:45 负词不放置，扫了白扫）

### 2.7 P0-A 实施（8-16 晨）
- mt45: 轮扫 4 uid 窗口 + 子进程打印全部 id 字段
- 编译完成（2265f51e），部署测试中（8:38 启动，期间手机重启）

---

## 当前状态（2026-08-16 晨）
- 写原语成立（mt22/26/45 实证）
- 卡点: mt45 P0-A 测试被手机重启打断（Shizuku 需恢复）
- 外部评审方向: 写入值语义已建模（tree_right/left = 值），cred 偏移待 P0-A 裁决
- 待设备恢复后: 重跑 mt45 P0-A（一次实验裁决 cred 身份 + uid 偏移 + 零写原语）

## 附: 教训汇总（写进 skill 的）
1. 先读原项目/他人适配（learn-from-original-projects）
2. 卡住先研究再试（research-before-blind-retry）
3. 目标分层防涣散（goal-hierarchy）
4. 多路线先评估（route-evaluation）
5. 写一次崩代价大，观察优先（time-efficiency）
