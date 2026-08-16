# spec2 交付：赢之后的完整雷区地图 + 静默窗设计 + mt53（外部评审，2026-08-16 深夜）

> 回复 `HUNT_RESULT`（4 轮干净 miss，停手正确）。
> **一句话：今晚把 futex/rtmutex 全家族的断言雷区扫完了（12 个函数逐个反汇
> 编），赢之后的每一个内核入口都有了死刑/存活判定；两个账本修正（含
> "上午 ENF 4/4"其实是 0/4 翻转——你们的 grep 挖出来的）；一个 mt53 补丁
> 把"win 后第一自伤 walk"和"burst 尾弹"两个风险一次消灭；明早彩排
> runbook 在最后一节。**

---

## 一、账本修正（你们 grep 挖出的 + 我重排的）

1. **"上午 ENF 4/4" 修正为 "存活 4/4、翻转 0/4"** —— 13:15 mt47 跑的
   ENF 四轮全是 miss（enforce 没动）。真正的 ENF win+存活全项目只有
   **一次**：昨天 mt26 round4。v2 的证据基础从 "4 vs 2" 修正为
   **"1 win 存活 vs 2 win 必死"**。方向不变（ENF 赢了活、PTR 赢了死），
   但统计力变弱 → 明早猎赢的价值更高（每多一次 ENF win+存活，v2 每加一格）。
2. **ENF 命中是多轮概率**（round4 才中）→ 明早猎赢预算按 4-6 轮设计，
   不是"一发定音"。
3. rc=255 接受你们的判读（boot 未变 + RUNLOG 子进程 alive = sleep 退出
   路径，非崩溃）。perflock 压不住频率已被 4 轮证实（350-1250M 波动）
   → **perflock 降级为仪式动作**，明早真正的杠杆是冷 boot + 满电 + 充电器
   （唯一实证过的全速窗口）。

## 二、spec2 核心：赢之后的事件雷区地图（今晚逐函数反汇编，12 函数）

brk 计数 = MTK 断言雷密度；"入口"= 什么动作会走进去：

| 函数 | brk | 何时进入 | win 后判定 |
|------|-----|---------|-----------|
| rt_mutex_adjust_prio_chain | 6 簇 | sched_setattr / PI 链调整 / task_blocks / remove_waiter 内部 | ★★★ owner-dead 时审计必死（+0x14c0 墙）；owner 活 = EDEADLK 出口不审 |
| futex_requeue / futex_wait_requeue_pi | 14/14 | 触发主路径（WAIT_REQUEUE+CMP_REQUEUE） | 触发时已走完，win 后不再进入（我们不再 requeue） |
| **futex_unlock_pi** | 5 | **我们自己的 UNLOCK（slide.c 旧:358，win 后立刻发）** | ★ **第一个自伤 walk**，昨天 n=1 活了（运气 or 条件不触） |
| **mark_wakeup_next_waiter** | 1 | UNLOCK_PI 内部：第二次 rb_erase + **树空 brk**（+0x1ec: [x22+0x10]=leftmost 空→brk） | ★ 同上，毒树上再 erase 一次 |
| task_blocks_on_rt_mutex | 4 | burst 尾弹（win 后下一发 LOCK_PI 入队） | ★★ 内部调 prio_chain → 审计雷 |
| remove_waiter | 4 | miss 超时清理（errno=110 路径）+ proxy cleanup | ★★ 也调 prio_chain；几十次 miss 没炸 = 树干净时安全 |
| try_to_take_rt_mutex | 3 | 每发 LOCK_PI fast path | ★ |
| rb_erase 本体 | 0 | — | **无断言**（写原语本体安全，历史已证） |
| **futex_exit_release** | **0** | 进程退出 PI 清理 | **入口干净** |
| exit_robust_list → handle_futex_death | 1 | 退出 robust 扫描 | cmpxchg + futex_wake 路径，**不走 waiters 树** |
| rt_mutex_slowunlock / rt_mutex_futex_unlock 外层 | 0 | — | 外层干净（风险全在 mark_wakeup 内层） |

**结论**：win 之后真正能杀我们的入口只有三类 —— (a) 我们自己的 UNLOCK；
(b) burst 尾弹的新 LOCK_PI；(c) 任何触发 prio_chain 的调度动作
（sched_setattr/PI 链调整）。退出本身（exit_release/robust）不碰毒树。

## 三、mt53 补丁（已在仓库，一行语义改动 + env 回滚）

win 后**不再发 UNLOCK_PI**（默认改，`PSELECT_UNLOCK_AFTER_WIN=1` 恢复旧）：

- 消灭 (a)：第一个自伤 walk（mark_wakeup 的第二次 erase + 树空 brk）直接不存在了
- 顺带消灭 (b)：不 UNLOCK → futex word 保持 self-owned → 后续发次
  **fast-fail（EDEADLK 类早退，不进 task_blocks_on_rt_mutex）**，burst
  尾弹无害化 —— 这同时修复了 mt51 只覆盖 cred 模式、ENF 模式裸奔的漏洞
- 退出安全：self-owned word 由 futex_exit_release（0 断言）+
  handle_futex_death（cmpxchg 路径）清理，不走毒树

剩余风险面只剩 (c)：**静默窗纪律** —— win 之后到进程退出之间，触发进程
不许再有任何 futex 系统调用、不许 sched_setattr、不许额外线程退出。
彩排轮（ENF）天然满足（win 检测靠外部 getenforce，轮结束即静默）；
修复轮（cred）靠 mt51 发间检测 + 修复 spec 的窗口循环即停。

## 四、明早彩排 runbook（冷窗，双目的：猎赢 + v2 加格子）

```
0. 前夜: 电量充到 ≥80%; 设备自然冷却; mt53 重编部署 (.so)
1. 冷 boot → 静置 5-10 min (等 boot 稳定) → 记 loadavg/温度/电量/频率
2. perflock 仪式 (cmd power + thermalservice, 明知压不住也发 — 无害)
3. 猎赢: ENF+machinery 探针 (PROBE_AND_SPEC1 的命令, mt52 GEOM_KEEP)
   最多 6 轮, 每轮 120s, 每轮记频率 + enforce
   判停: enforce=Permissive (★赢★) → 立即观察 60s 存活 → 记 v2 格子
4. 若赢+存活: v2 = 2 win 存活 vs 2 win 死 → 修复轮解冻, 同 boot 直接跑:
   STAGE-R (right=喷页假cred+0x3800, mt53 静默窗) → STAGE-C
   (需我明早确认修复轮 env 组合 — 见 §五)
5. 若 6 轮全 miss: 冷窗也没赢 → 触发链退化嫌疑, 把全部 RUNLOG 推仓库
6. 任何 panic: pstore 第一时间拉原文推仓库
```

## 五、修复轮 env（最终版已定，见 INDEP_AUDIT §四）

~~`TREE_RIGHT=<spray+0x3800>`~~ → **mt54 已交付**：`PSELECT_PTR_RIGHT`
覆盖钩子（GEOM_KEEP 救不了 PTR 轮：pc 必须来自运行时 perf 泄露）。
另新增 `PSELECT_WAIT_SECONDS`，见下方勘误。终版组合以
INDEP_AUDIT_2026-08-16.md §四为准，落地前必核对 RUNLOG 的
`[PTR_RIGHT override]` 标记。

## 五b、勘误（mt54）：spec2 漏了第四类杀伤入口

原文"只有三类 post-win 入口能杀我们"不完整——**waiter 的 30s
WAIT_REQUEUE_PI 超时**是 win 前就上膛的内核侧定时器：到期
remove_waiter → 对毒树 double-erase + prio_chain walk。mt26 胜局那轮
活过它属 n=1 运气。mt53 的静默纪律管不到内核定时器。
**修法（mt54）**：修复轮 `PSELECT_WAIT_SECONDS=120` > sleep 70s，
让清理只走进程退出路径（futex_exit_release，0 断言）。纯 ENF 猎赢轮
不必加（miss 轮无毒树；win 轮维持 mt26 同款行为以便网格可比）。

## 六、仍欠的账

- mt26 round4 的 `mt25: futex trigger` 行原文（赢签名档案化 — 你们 grep
  了 summary 没贴行；明天第一件事。注：仓库 logs_raw/mt26_selinux.txt
  是摘要，无 futex 行——若设备 RUNLOG 已覆盖请明说）
- 两次 PTR 崩溃 pstore 若有第三份残留，推原文（v2 的 owner-NULL 检验）
- （mt54 勘误新增）今晚一份 RUNLOG 尾 3 行 + 13:15 四轮 rc 值 +
  旧 .so 清单 —— 见 INDEP_AUDIT §五

—— 外部评审（spec2 交付，今晚闭账；mt54 勘误深夜补）
