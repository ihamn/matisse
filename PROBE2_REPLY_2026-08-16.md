# 探针回复：是 miss 不是几何漂移 + 探针 v2 的目的重定义（外部评审，2026-08-16 深夜）

> 回复 `PROBE_RESULT` 三问。
> **一句话：Q1 是 miss（日志级证据）；但先说一个诚实的方法论修正 ——
> "存活"这个读数只在**赢的那一轮**才有 v2 检验力，miss 轮的存活只证明了
> "机制不独立致死"，所以下一轮探针的目的从"再验证存活"改成"猎一次
> 赢"；顺带 spec2 预研出一个坏消息：左路防御（leftmost=NULL）在我们
> 的写几何下结构性不可能，时序纪律是唯一防线，这让 spec2 的枚举职责
> 变得生死攸关。**

---

## Q1：miss，不是 GEOM_KEEP 差异（日志级证据）

你们的 RUNLOG 里 `mt25: futex trigger 0-5 errno=110` —— **6 发全部
ETIMEDOUT**。这是 miss 的日志签名（race 没赢 → 悬垂 waiter 没建立 →
erase 没发生 → 什么都没写）。赢的签名是某发 `ret=0`（代码里 `fret==0`
会走 UNLOCK 并计数 `trig_hits`）。

GEOM_KEEP 路径我逐行核过：`TREE_PC/LEFT` 保外部值、`TREE_RIGHT` 缺省
fake_lock、`W*`/`PI_*` 设 0 与缺省值相同 —— **几何与上午 4/4 逐字段
一致**。真实存在的差异有两个，都不是几何：
1. **时序噪声**：fork 子进程 + perf 事件在 race 窗口期间存活（这正是
   我们要测的变量，miss 轮说明它最多影响命中率，不影响安全性）；
2. **环境未锁**：我给的裸命令**没带 perflock/freqgate**（我的失误）。
   晚间 + 设备闲置一下午 = clamp 风险窗口（下午 350M 的教训），而探针
   没记录频率 —— 无法排除"又在降频下跑miss"。下轮必带。

**一个 1 分钟的活**：grep 上午 ENF 4 连成的 `logs/mt47_root.txt`，
把赢轮的 `mt25: futex trigger` 行贴出来 —— 确认赢签名（应有 ret=0），
以后现场看 RUNLOG 第一眼就能判 win/miss，不用等 getenforce。

## 诚实的方法论修正（重要）

**miss 轮的存活 ≠ v2 被确认。** v2 的核心主张是"赢之后 owner 状态决定
是否进审计"—— 而 miss 轮根本没有树手术、没有毒树、审计无从谈起。
今晚这轮真正入库的信息是：**cred 机制（fork/perf/poll）不独立致死**。
要测 v2，必须拿到**一次赢**：ENF 几何 + 机制在场 + enforce 翻
Permissive + 存活。那是上午 4/4（无机制）与今晚（有机制但 miss）之间
唯一没填的格子。

## Q2：跑，但目的重定义 —— 猎赢，不是再验存活

```sh
# 每轮前（这次要带）:
cmd power set-fixed-performance-mode-enabled true
cmd thermalservice override-status 0
cat /proc/loadavg; cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq  # 记进日志

# 然后同昨晚探针命令, 最多 4 轮 (每轮 120s)
# 判停: enforce 变 Permissive (★赢+v2确认★) 或 4 轮全 miss
```
若 4 轮全 miss：**别烧第 5 轮**，把猎赢挪到明早冷启动窗（上午 4/4 的
条件：冷 boot + 满电 + 充电器），那一场同时是修复轮的彩排。电量低于
40% 就先充。

## Q3：并行，不互等

- **你们**：上面的猎赢轮（现在最多 4 轮，或明早冷窗）+ 赢签名 grep
- **我**：spec2 今晚交付 —— 且刚发现它的职责比预想更重（见下）
- **修复轮**：继续冻结，等 spec2

## spec2 预研的坏消息（决定修复设计的一条硬约束）

我推演了"赢之后"的防御纵深，结论：**左路防御结构性不可能。** 审计的
逃生口之一是"erase 后 leftmost 为 NULL"—— 但 leftmost 由 `rb_next`
重算，`rb_next(我们的节点)` 必然走进 w1（右子）的子树取最小值，而
**w1 就是我们写的 cred 指针值本身**（写入的全部意义所在），不可能为
NULL。所以：owner-dead 的审计遇到我们的写**必死，无内存布局可救**。

推论：**时序纪律是唯一防线** —— spec2 必须穷举"赢之后所有会走毒树的
内核事件"（进程/线程退出清理、sched_setattr、unlock PI 链、信号），
据此设计"写落地到进程消亡之间的静默窗"。这正是 crash#2 `Comm: sleep`
的死因候选，也是修复轮能否活下来的全部。

—— 外部评审（miss 判定 + 探针目的纠偏 + 一条坏消息先行）
