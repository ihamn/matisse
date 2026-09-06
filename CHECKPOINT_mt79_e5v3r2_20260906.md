# CHECKPOINT — mt79/E5v3r2 + 09-06 凌晨现场轮复盘 (R✓ / E5v3安全拦截 / C中断+软重启)

## 现场时间线 (2026-09-06 01:09-01:20, boot=ab549482 全程未变 → 内核始终存活)
1. 01:09 R 轮(CPU6, mt78 build): perf task=0xffffff80426e4a00 (198/256票),
   6 发风暴全正常 → **CapEff=000001ffffffffff 落地 ✅** (连续第 8 次 R 成功)
2. 01:11 E5v3: fake_lock=0xffffff81062c04d0 (页基址+0x4d0, 尾字节 d0) →
   mt78 运行时校验器 ABORT ✅ 零事故 (设计目标达成)
3. 01:14-01:17 C 轮 (无 E5, 直打 R-child, stage C): 触发链完整
   (EDEADLK 35 → FWRQ 110 → UNLOCK_PI 0 → pselect 窗口上膛 6 发)
4. ~01:18 **软重启** (framework 级; boot_id/uptime 连续, 非内核 panic)
   → C 进程被连带杀死, 窗口内是否命中【无法判定】; logcat 滚动/dropbox
   拒读, 用户态死因取证到头 (system_server 死亡, 与历史自发软重启同型;
   load 16.7 + 每轮克隆 500+ 进程的内存压力是重要诱因)

## 根因修正: mt79 (E5v3r2)
- fake_lock = payload_base+0x1350, payload_base = page_base-0xe80 → 非页对齐!
- 修正: E5 child 用 ★page_base★ (真页对齐): SPRAY=page_base (byte0=00 →
  enforcing=0), SPRAY1=page_base+1 (byte0=01 → enforcing=1)
- byte2=0x2c ≠0 (initialized 保留); 校验器 (byte0∈{0,1}, byte2≠0) 不变
- STORE(b) 污染页首 0xe80 布局零区 — put64 布局从不写该区, 牺牲安全
- preload.so SHA256: 75728bb8b2e31c4cb91165859016d0866635b3ba8a888cf00e96ad5333c9e85e
  已部署 /data/local/tmp/preload.so + 工作区 preload_mt79.so

## 现场纪律更新 (软重启教训)
- ★load gate 不再放宽: >15 一律不跑★ (01:17 轮 load 16.7 是本项目首次
  顶着超载开火, 结果就是软重启 — 相关性已记录)
- 每轮 storm 克隆 500+ 进程; 连续轮之间至少隔 3-5 分钟让内存回收
- 软重启 ≠ 内核崩溃 (boot_id 判别): uptime 连续 = framework 重启, pstore
  不会有新 panic, 别浪费轮次找

## 下一步
1. E5v3r2 (SPRAY 默认) 现场一轮 — 判定 v1 黑屏根因 (H-A vs initialized=0)
2. 无 E5 的 C 轮重试 (mt73 sethostname 信标 + R 先行) — 本次 C 因软重启
   中断, 内核全程无恙说明双 erase 也不 panic, 可在低负载下重试
3. C 铁证 (hostname=glroot / Uid:0) 拿到即 root 到手; E5 只剩 KSU 加载用途

## 补充 (08:44): E5v3r2 两轮 fork 模式复盘 + 软重启 #2
- 第 2 轮 (08:29, load 13.6 达标, 屏幕常亮): rc=124 跑满, out 冻结在
  "found 3 collisisons" → 卡死在 KernelSnitch 之后的 mm_struct 暴力扫描
  (8 线程 VA 扫描, 内存密集) → D 状态堆积 load 2631 → system_server 饿死
  → framework 软重启 #2 (boot_id ab549482 仍连续, 内核零伤, enforce 未动)
- 两轮对照: 第 1 轮扫描通过但息屏毁窗口; 第 2 轮屏幕正常但扫描 thrash。
  共同点: fork 模式 E5 轮的扫描阶段对内存压力极敏感 (9h uptime + swap
  3GB + bilibili 1.2GB RES)。
- ★对策★: ① 回归 mt77 已验证的 external 序列 (R 先行 → E5v3 external
  PSELECT_TASK=<R-child> → C → E5R); ② 跑前关重应用清内存; ③ R 轮本身
  8/8 稳定, 即使 E5 失败仍有 R-child 可打 C 信标; ④ 轮间冷却 3-5 分钟。
- E5v3r2 几何本身已验证正确 (第 1 轮 mt79 打印: enforcing=00
  initialized@+2=36, 校验器放行, 触发链全绿) — 只欠一个稳定的执行环境。

## 理论分析定案 (10:58): E5 三连卡死 = kill_child waitpid 阻塞, 非几何非回归

### 证据链
1. git 考古: 27d06cc(mt77 构建) 之后引擎源码零改动 → mt78/79 构建 ≈ mt77 构建,
   kernelsnitch.h 同为 exploit/src 的 7月16日版(mt61 配方同一来源) → 排除构建回归
2. 卡点定位: 三次卡死输出都停在 "found 3 collisisons"(leak child 的最后一句,
   ks->state 已置 COLLISIONS_FOUND, find_collisions 已完成) — 父进程的
   "spray children killed" 再未出现 → 父进程卡在 post/spray kill 循环
3. kill_child (util.c:487): kill(SIGKILL) + **阻塞 waitpid**。34 个 spray
   子进程 + 543 克隆峰值 + 内存压力 → SIGKILL 的子进程困在 D 状态
   (futex/memfd 不可中断内核路径) 不死 → waitpid 无限等
4. 三种 rc 形态全部解释: rc=124(08:29, sleep180/timeout250 阻塞到超时);
   rc=0(10:47, 构造器在后台线程, sleep130 主线程到点 exit(0) 把阻塞线程
   一起带走); rc=255(08:11, 校验器 ABORT 预期路径)
5. 源码自认: util.c:862 注释 "ks collision finding is flaky/slow"
6. mt77 为何能过: E5v2 当晚通过扫描 → D 状态排空时间是概率性的, 与系统
   内存状态强相关; 今日 12h uptime + swap 压力下恶化

### 修复方向 (择一或组合)
A. 【零代码】给足时间: E5 轮 sleep 350/timeout 400, 赌 D 状态最终排空
B. 【代码】kill_child 改非阻塞: 先全部 kill, 再 WNOHANG 轮询收尸 + 有界
   等待(如 30s), 超时放弃 reap 继续推进(waitpid 只为防僵尸, 不阻塞主流程)
C. 【代码】减少克隆规模 (272+204+33+34 → 砍半), 降低 D 状态堆积概率

### 判别实验
A 跑一轮: 若 400s 内完成 → 阻塞有限, 方案 A 即可; 仍冻结 → 阻塞无限,
必须上方案 B (WNOHANG 补丁)。

## ★ 11:38 定案: 第二触发轮踩爆 R 毒化 PI 链 — kernel panic 实锤 (pstore)

### panic 现场 (11:28:46, boot b07e72d1, uptime 3046s)
- bootreason=kernel_panic (本次非 longkey)
- pc: rt_mutex_adjust_prio_chain+0x9fc/0x1948, Oops 96000004
- 坏指针: x19=0x0008000000000000 (被遍历的 waiter 节点=垃圾), x8=x19+0x40
- x1/x27 = 0xffffff811a0a84d0/8 = 喷页 fake_lock (base+0x4d0 特征吻合)
- x25/x5 = 0xffffff8116ba64xx (同喷页区) — PI 链正在穿我们的假锁区
- 触发者 T628728 = 探针轮(E5 external, PSELECT_TASK=<11:15 链的 R child>)

### 机制
R 轮 erase 后, R-child 的 rtmutex waiter/PI 树里留着我们的假节点(部分词
已写/部分垃圾)。对该 child 的**任何第二次 futex/rtmutex 触发**(C/E5
external)都会让内核 walk 这棵毒树 → prio_chain 解引用垃圾 → panic。
0x0008000000000000 = 半成品 waiter 词(部分 fd_set 覆写残留)。

### 今日全部崩溃归因(重排)
| 时间 | 轮次 | 结果 |
|---|---|---|
| 01:18 | C external on R-child (R 01:10 落地) | framework 死 (软重启#1) |
| 08:44 | 链 C 阶段 on R-child (R 08:10 落地) | framework 死 (软重启#2) |
| 11:29 | E5 probe external on R-child (R 11:18 落地) | **kernel panic** |
→ 三次全是"对已毒化 child 的二次触发"; 与 E5 写本身无关(从未发射)。

### 剩余独立谜团
- KernelSnitch 扫描冻结 (fork/standalone 4/4): kill_child 补丁无效,
  父线程在 pre/post kill 区间静默失联, 机制未明 — 需活体 wchan 解剖

### 战略结论
1. §6.4 的 R→E5→C→E5R 同 child 背靠背链在本内核上**结构性不安全**, 废止
2. R 几何单发 10/11 — 引擎对单轮写完全可靠
3. 下一步三选: (a) C 改 fork 模式(需先解扫描冻结) (b) 研究 R 毒化树的
   排毒/复用策略 (c) 每 boot 只打一轮 R+C 一次性组合(接受毒化风险)

## ★★ 终版理论 (12:33): 毒化树随机涂抹器 — 三种后果统一解释

### hostname EACCES 之谜 (用户直觉正确, 非 sidtab 全局损坏)
- 判别: 同路径 boot_id 读取正常 (sidtab 全局损坏排除);
  logcat 零条 hostname/sysctl avc (SELinux 拒绝排除);
  stat+read 双 EACCES (proc_sys_permission 的 test_perm 失败 = 条目 mode 损坏)
- 定位: kern_table 的 hostname ctl_table.mode 被野写改写(→0),
  kern_table 在内核 .data — **正是我们全部写目标所在的 image-data dmap 窗口**

### 统一机制
R 轮 erase 留下毒化 freed-waiter 状态(child 的 rtmutex 域)。child 存活数小时,
期间任何 futex/sched 唤醒都可能 walk 毒链 — rt_mutex_adjust_prio_chain 的
遍历伴随写操作(prio 传播/waiter 摘挂) → **每次 walk = 一次随机内核涂抹**。
后果三态:
  a) 走到未映射垃圾 → kernel panic (11:29 实锤, x19=0x0008000000000000)
  b) 涂抹伤及敏感结构 → framework 死 (01:18/08:44/12:23)
  c) 涂抹落点无害化 → 静默累积 (kern_table.hostname.mode 即一例)
每次 R 轮 = 埋一颗雷; child 活越久雷越多 → 今日系统逐步劣化完全可解释。

### 设计修正
1. ★信标通道换 uname -n★: /proc/sys/kernel/hostname 读路径已死(且不可靠),
   uname -n 直读 utsname 无权限依赖 — mt73 验证一律改用 uname -n
2. PSELECT_TASK 二次击打前必须校验 child 心跳新鲜度 (stale task = 随机写)
3. R 落地后 child 应尽快退场(或 detox), 不留活雷

## ★★ 13:05 突破: "扫描冻结"翻案 + E5 miss 真因 = 消费者结构性饥饿

### fresh-boot E5 fork 轮 (13:04, W.out 全文 10440B)
- 扫描阶段一次通过 (fresh boot 解锁) → SLIDE page prepared ✓
- **8/8 attempt 全流程跑通**: mt79 几何正确(enforcing=00 initialized=5e),
  触发链全绿 (EDEADLK→FWRQ→UNLOCK_PI→LOCK_PI) — 没有"冻结"这回事!
- 8/8 MISS 签名完全一致: sched_ok=0, sched attempt=0 ret=0,
  **落点 = 窗口关闭 + 20ms** (20020/20008/20019ms...)
- wchan 活体: 每波 attempt = 3 线程 (do_select + nanosleep + R 自旋),
  消费者被同核窗口线程压死, pselect 退出瞬间才被调度

### 未决判别 (30s 窗口实验, W30.out 已在 /data/local/tmp 等待读取)
- 落点若随窗口走 (~30.02s) = 结构性从属 → 修核亲和性 (consumer 让出 CPU6
  或换小核)
- 落点若停在 ~20s = 绝对饥饿 → 30s 窗口直接修好
- 该轮 13:19 发射后系统崩溃, 数据在盘上等下次会话

### 今日终账
- R 11/13, E5 落地 0/6 (但 13:05 轮已证明全流程机械上通顺, 只差 sched 时序)
- 崩溃 7 次; kern_table.hostname.mode 野写损坏确认 (uname -n 可用,
  /proc 读路径死)
- mt80 引擎 + kill_child 非阻塞补丁在位; 信标改 uname -n 配方就绪
- 下次会话动作: ① 读 W30.out 判别饥饿类型 ② 按判别结果修 consumer 调度
  ③ E5 fork 轮重打 (fresh boot + 窗口修正) ④ 落地即 uname -n 验证信标

## ★ 终极归因 (13:30): 30s 窗口 panic = 同进程重试毒化 (mt49 铁律重现)
- bootreason=kernel_panic, pc=rt_mutex_adjust_prio_chain+0x1788 —
  与 PSTORE_TRACE_2026-08-16 (mt49) 完全同款, 触发路径 rt_mutex_adjust_pi←sched_setattr
- test_mt49_root.sh 头部早有铁律: "同进程多 attempt 已判死(pstore): 二触后
  任何 sched_setattr → prio_chain 崩" — E5/CRED 模式 8 attempt 循环 = 7 次
  进程内重试, 必崩。本次设计时未重读此约束, 教训: 开火前必查档案死刑清单
- 30s 窗口判别实验实际"成功": 消费者进窗了(sched 在窗口内执行), 饥饿已修 —
  但暴露更深层: attempt N 的毒 waiter 被 attempt N+1 的 sched 踩爆
- ★E5 正确形态: 单进程单写 (1 attempt) — R 轮 11/13 安全正是这个原因★
- 20s 窗口时代的 "miss" 本质 = mt66 护栏拒绝盲写 = 系统自保, 不是故障

### 下次会话唯一主线
1. 读 W30.out (/data/local/tmp 跨重启保留): 确认 attempt 1-2 是否已在窗内
   开火(写入是否发射)
2. E5 单 attempt 化 (PSELECT_CRED 的 8-attempt 循环对 E5 无意义, 砍到 1)
3. fresh boot + 30s 窗口 + 单 attempt → E5 首次有意义的落地判定
4. 信标验证一律 uname -n

## ★ 13:58 活体解剖: 窗口期线程现场 (wchan2_dump, pid=32579)
30s 窗口期 (13:54:05-13:54:26 三连拍):
  tid=25525 do_select S   ← pselect 阻塞中
  tid=25526 nanosleep S   ← 看门狗
  tid=25527 wchan=0 R     ← ★全程空转烧核, 零 sched 日志★
  tid=32579 nanosleep S   ← 主线程
- 单写 1/1 ✓ (RETRY=1 修复生效, 无 panic, boot 不变)
- 判别定案: 30s 窗口 sched 落点 30028ms = 窗口关闭+28ms — 结构性, 与窗口
  长度无关 (20s→20.02s, 30s→30.03s)
- 矛盾点: 消费者设计 = 窗口+50ms 打 6 发 sched 突发 (enter_delay=50000usec),
  但窗口期一行 mt19b 都没有 → 消费者从未进入 burst 代码; 25527 在空转什么?
- 下次会话开场任务: 读 slide.c/main.c 线程创建架构, 映射 tid 角色表,
  找消费者 burst 的触发条件为何在窗口内永不满足
- E5 现状: 引擎机械全通, 唯一缺口 = 消费者 burst 时序; 这是纯用户态 bug,
  不再涉及内核风险, 修复成本 = 一次代码审读 + 一轮验证

## ★ 14:40 硬停决定 + 今日终账
- mt81 诊断轮 (E5 fork, 单写, 心跳仪器化) 再次导致整机重启 — 第 3 次
  kernel panic, 全部发生在 E5 fork 轮的扫描/风暴期
- ★结论: KernelSnitch 扫描 methodology 在本机 = panic 抽奖 (今日 3/7)★
  与参数无关 (8att/1att/20s/30s 窗口/内外部模式全试过)。根因未明
  (疑似 500+ 克隆的 futex pile-up 踩 rtmutex PI 状态), 静态分析无法
  再推进 — 需要的是内核侧证据 (pstore 栈已收集 2 份, 均 prio_chain)
- 全部武器已停; /data/local/tmp 上等待读取: H.out (mt81 心跳 — 若轮次
  走过扫描期, 心跳会回答消费者问题; 若死于扫描期则只有前段日志)

## 下次会话路线 (按优先级)
1. [零成本] 拉 H.out 读 mt81 心跳 — 消费者问题可能已有答案
2. [决策] E5 路线三选:
   a. 修消费者后继续 fork 轮 (接受 ~40% panic 抽奖, 每轮 = 一次重启)
   b. 降低扫描风险再试 (克隆减半/thread_cnt 降/轮间距拉长) — 未验证
   c. E5 彻底 park (09-05 手册先例), root 走 C 路线: C 也在同一风暴里,
      扫描风险相同 → 本质是"风暴 = 风险"的接受度问题
3. [无论选择] root 判据 = uname -n; 证据落盘 = root_alive.txt; 崩了不亏
## 铁律新增
- 开火前必查档案死刑清单 (mt49 同进程重试/本次 KernelSnitch panic)
- 同一轮次累计失败 ≥2 次 → 强制停, 不许"再试一把"
- framework 软重启后必清扫残留进程 (orphan sleep/preload)

## ★★ 14:45 H.out 心跳破案: 消费者无辜, FWRQ 分钟级延迟才是真凶
- mt81 心跳 (15312 行): 消费者全程 seq=0 seen=0 规矩等待 — 从未被饿、
  从未坏掉; mt61 窗口行在日志最末尾 (waiter 线程 FWRQ 实际阻塞分钟级,
  3s 超时变分钟 = KernelSnitch 堆积桶 4096 futex 的桶锁/PI 竞争)
- 窗口开启后 ~2 拍内即死 (panic/重启) — 消费者第一发 burst 都没来得及打
- 候选 bug #2: 消费者 `seen` 为线程生命周期局部变量, 首次 publish 后
  seen=1 永不复位 → 多 attempt 轮后续 publish 全被 seq==seen 吞掉
  (解释 13:04 轮 8 attempt 仅末次 close+28ms 一行 mt19b; 若线程为
  每 attempt 新建则此候选作废 — 待查 pthread_create 调用位置 line 837)
- ★修复方向排序★:
  1. FWRQ 延迟: 触发序列整体分钟级推迟是主敌 — 选项: waiter 线程改
     futex 等待为带唤醒重试/缩短堆积窗口/查桶锁竞争源
  2. seen 复位: 消费者循环加 `if (seq==0) seen=0;` (一行, 恢复多轮响应)
  3. 消费者唤醒改 futex 事件驱动 (替代 yield 自旋, 顺带消灭空转烧核)
## 状态: 引擎机械全通已三度证实; 现在是两个已定位的用户态 bug
  (FWRQ 延迟 + seen 复位), 都是坐下来可修的代码, 不再需要抽奖

## ★ 15:05 V.out 破案: 触发机制在 leak child 里, 消费者 CPU6 被剥夺 30s
- slide_child_leak_stext() (slide.c:857) = waiter/owner/consumer 三线程
  的宿主 — 整个触发机制在 fork 出的 leak child 进程里跑
- mt82 跳变行: child 消费者 t=0ms 即见 seq 0->1 (发布零延迟, 发布机制
  完全正常!) 但 burst 打在 t=30031ms — 中间 30s 被剥夺 CPU (pin CPU6)
- 双消费者读数差解释: 心跳 tid=26780 (seq=0 永远) = 另一进程的消费者
  (身份待映射); 两者内存独立所以读数不同
- ★下一试验 (纯 env, mt82 二进制不变): PSELECT_CONSUMER_CPU=7
  (X2 prime) — 把消费者挪离被压死的 CPU6。若 mt19b 落在窗口内
  (t≈50-100ms) → 写发射 → enforce=0

## 15:20 CPU7 试验: 换核无效 → 阻塞在内核态, 非调度问题
- CONSUMER_CPU=7 (X2 prime): 落点仍 30030ms, 与 CPU6 完全一致
- 排除: 核竞争/nice 饥饿/窗口长度/发布时机(发布即时可见 t=0ms)
- ★新定位: 消费者 burst 的第一发 sched_setattr_tid(26778) 系统调用
  本身在内核里阻塞 ~30s — __sched_setscheduler → rt_mutex_adjust_pi
  → walk 风暴 futex 堆积搞乱的 PI 链 → 出 kernel 时窗口已关 → mt66
  护栏弃写 → miss。三态后果的"温和态"就是这个 30s 内核漫步。
- 与 panic 的关系: 同一条 walk, 撞上未映射 → panic(11:29); 撞上可
  磨完的链 → 30s 漫步(本轮); 涂抹落点随机 → framework 死/野写

## 下次会话主线 (按此顺序, 数据全在 /data/local/tmp + logs_raw)
1. 读 V.out/V7.out/W.out (已存 logs_raw 与 sdcard): 状态机全量数据
2. 核心问题: sched_setattr 对 pselect 阻塞中的 waiter tid 的
   adjust_pi walk 为何磨 30s — 读 util.c sched_setattr_tid + 内核
   rt_mutex_adjust_prio_chain 路径 (pstore 两份栈可对照)
3. 修复候选: (a) burst 目标改 owner tid 或交叉 (b) 缩短/绕过 walk
   的触发路径 (c) 窗口长度 >= walk 时长 (暴力但可行: 窗口 60s+
   walk ~30s → 写在窗内落地!)
   ★(c) 立即可试: WINDOW_SECONDS=60, 消费者 burst 落点 ~30s (walk
   结束点) → 30s < 60s → 写在窗内! mt66 护栏检查 go 仍=1 → 不弃打!
4. root 判据: uname -n; 铁律: 开火前查档案死刑清单

## ★ 16:10 C3 复盘: burst 全发 + "C 未落地"结论不可信 (致盲判据缺陷)
- mt83 no-break 生效实证 (C3.out): 5 发全打, waiter/owner tid 交替,
  walk 磨合 (30s → 即时 → 1s×3), 全部 ret=0 — burst 机械完全修复
- C 未中? ★判据有缺陷★: child 致盲后 status 文件冻结在旧值
  (uid=2000 euid=2000 CapEff full) — 与"C 没落地"观测完全相同!
  status 文件无法区分 "C miss" vs "C 落地+致盲"
- ★判据升级 (下一步第一动作)★: shell 有 readproc 组 → 直接
  `cat /proc/<child_pid>/status | grep Uid` — 读的是 child 的真实
  cred, 不受 child 自身致盲影响! 若 euid=0 → C 其实早已落地 = root!
- burst 后仍 miss 的机制修正: 5 发 sched walk 跑的是 waiter/owner
  任务的 PI 链, 毒化 fdset 节点(freed 栈槽)是否被 walk 到 = 核心未解
  (R 落地 12 次证明 walk 能到 R 几何的节点; C 几何同构应该也能到
  → 所以 "C 可能已落地" 不是空想)
- 历史数据回看: R 轮 CapEff 满 = real_cred 已换; 若某轮 C 也落地,
  child euid=0 — mt47 时代从未直接读过 child 的真实 Uid 行!

## ★ KSU 官方文档研读结论 (18:3x) — .ko 适配判定 + 正确路线
1. ★kernelsu_prep 里的 v3.2.5 .ko 不能用★: KSU 1.0+ 放弃非 GKI, v3.2.5 是
   GKI 向构建; 符号校验实测 (206 依赖 vs 内核 __ksymtab_ 7179 条):
   kallsyms_lookup_name/commit_creds/prepare_creds/selinux_state/
   security_context_to_sid/path_mount/ksys_unshare/__put_cred 全部未导出
   → finit_module 必在 Unknown symbol 失败, vermagic bypass 无济于事
2. ★正确路线 (官方文档)★: 非-GKI 集成最后支持版本 = KSU v0.9.5;
   把 KSU driver vendor 进 matisse 内核源码树 (kernel/setup.sh -s v0.9.5),
   CONFIG_KSU=m 编出 kernelsu.ko (vermagic 5.10.209-android12-9),
   经 root 窗口 insmod = 官方 late-load 模式 (安装页明文: 临时 root 可加载
   LKM, 不刷 boot 不触发 AVB 不变砖)
3. 未导出符号的解法: kprobe-based kallsyms 解析 (标准 rootkit 手法,
   ~50 行; register_kprobe 已确认被内核导出 ✓)
4. 前置: matisse 内核树可构建 (_research/android_kernel_xiaomi_matisse-main
   在手; 构建环境 = 下次会话任务); 一定要能编出与设备内核一致的模块
   (MODVERSIONS CRC 或 flags=3 绕过)
5. 管理器 APK 已 pm install 成功 (18:20); 打开显示"不支持/未安装"属预期,
   内核 .ko 装载后 manager 经 prctl 探测即转绿
