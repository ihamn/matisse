# pstore 栈裁定 — crash#2 机制修订 + mt49 免疫确认 (2026-08-16)

> 回复 `PSTORE_TRACE_2026-08-16.md` 四问 + `FIELD_UPDATE_2026-08-16.md` 的未决点。
> **一句话结论：crash#2 实锤是 prio_chain requeue 路径上的 waiters-tree 一致性断言
> 被毒树踩中，不是 rb_insert rebalance。根因（同进程二触 + 毒树）不变，
> mt49 的 RETRY=1 依然是对症结构解，无需改动，直接跑。**

---

## 一、+0x1788 是什么检查（指令级，可复核）

`rt_mutex_adjust_prio_chain` @ `0xffffffc0081eae38`（kallsyms 实证，size 0x1948）。
崩溃点 `+0x1788` = `0xffffffc0081ec5c0`，是 **6 连发裸 `brk #0x800` 断言簇**
（`+0x1784..+0x1798`）的成员之一 —— 无 printk 的 `BUG_ON`。

崩溃路径（唯一入口链）：

```
+0x3e0: tbz  w26, #0, +0x404      ; if (!requeue) → 出口[8](解锁+put_task)
+0x3e4: ldr  x8, [x27, #0x10]     ; x27=lock, x8 = lock->waiters.rb_leftmost
+0x3ec: cbz  x8, +0x49c           ; 无 waiter → 跳过 dequeue-fixup
+0x3f0: ldr  x9, [x8, #0x38]      ; x9 = leftmost_waiter->lock   ★ WAITER_LOCK_OFF=0x38
                                   ;   (target_matisse.h 项目自标定, 假 waiter 几何一直在用)
+0x3f8: cmp  x9, x27              ; top_waiter->lock == lock ?
+0x3fc: b.eq +0x4a0               ; 相等 → 继续走 dequeue
+0x400: b    +0x1788              ; ★ 不等 → BUG  ← 崩溃 PC 的前一条
```

`+0x4a0` 流向 `+0x4e0..+0x4f0`：leftmost 修正（`str x9,[x27,#0x10]`）后
`bl rb_erase` —— **就是被我们劫持的 Call 1**（`rt_mutex_dequeue` →
`rb_erase(&waiter->tree_entry, &lock->waiters)`，CHECKPOINT_v30 钉过的写原语点）。

即：**+0x1788 = dequeue 前对 "本锁 waiters 树的 leftmost waiter 是否真属于本锁"
的一致性断言**。源码层面它不在 —— 上游 v5.10 和 android12-5.10 的
`kernel/locking/rtmutex.c` 此函数**一个 BUG 都没有**（android12 分支仅多 vendor
hook，diff 19 行全无断言；enqueue/dequeue 辅助函数也是裸 rbtree 操作）。这是
MTK 目标构建自加的树不变量 tripwire。6 个 brk 同族：prio_chain 里每次要碰
`lock->waiters` / `task->pi_waiters` 前都有一个，毒树走到哪死到哪，
crash#2 恰好死在最靠前的这个。

## 二、为什么 Comm:sleep 会走 rt_mutex_adjust_pi

`Comm: sleep PID 28091` **就是我们自己的载具** —— 脚本全程
`LD_PRELOAD=... /system/bin/sleep`。`sched_setattr` 也是我们自己发的：
`slide.c:300` consumer 线程在触发窗口内对 waiter/owner tid 循环调
`sched_setattr_tid()`（SCHED_BATCH 调窗，`util.c:165` → `SYS_sched_setattr`）。

内核侧链条：`sched_setattr(tid)` → `__sched_setscheduler(pi=1)` →
`rt_mutex_adjust_pi(task)` → `rt_mutex_adjust_prio_chain(requeue 路径)` →
沿 `task->pi_blocked_on → waiter → lock` 走进 **futex1 的中毒树** →
leftmost（init_cred 假 waiter）的 `+0x38` 是 cred 字段（cap 掩码一类的小整数），
≠ lock 指针 → BUG。

mt48 现场（RETRY=6 进程内）时序：attempt 1 的 stage-R 落地 → 真树 leftmost
毒化为假 waiter → attempt 2 的 consumer 又调 `sched_setattr(waiter_tid)` →
attempt 2 的新 waiter 正阻塞在同一 `v37_futex1`（静态词不清，slide_reset 不清
v37_*）→ prio_chain 走进毒锁 → 死。栈上 `task+0x778` + `init_cred` 是 attempt 1
R 写的残留物，与该时序自洽。

## 三、对 mt49 的裁定：结构性免疫，不用改

crash#2 的充要条件是**写落地之后、同进程内还有一次 PI walk 走进毒锁**。mt49 三重隔离：

1. **时序**：单次 attempt 内，`slide.c` 的 sched_setattr 全部发生在落地 futex
   齐**之前**；齐后 consumer 立即 `slide_consume_stop=1` 退出，同进程无后续
   PI walk。这就是 14 次幸存实验（mt25/26/28b/R0/ENF，全 RETRY=1，其中 ENF
   同样经 rb_erase 重定向写 selinux_state、同样毒树）无一崩的机理。
2. **进程**：RETRY=1 一进程一写，进程退出即无 attempt 2，毒树无从被二触。
3. **引用**：毒锁（futex rt_mutex）在触发线程内核栈上，futex key 是本进程
   地址 —— 进程死后无人可达。STAGE-C 新进程 v37_*/slide_* 静态词随 exec 清零，
   用的是自己的干净树；子进程 target 只 poll 状态文件，从不 PI 阻塞，
   任何 prio_chain 都走不进它。

**结论：prio_chain 断言与 rb_insert 假说是同一根因的两个死相，RETRY=1
一并杀死。mt49 照跑。**

## 四、STAGE-R 3 轮未落地的解释（Q4）

- round 1（fork 模式）：单发命中率历史 ~20-40%，未中属正常。
- round 2/3 rc=127：**外部模式本身没问题（main.c 已实现）**，是 getfield
  旧 bug 产的 env 值带空格（`task=0x.. uid=2000 ...`）→ `env` 无法 exec → 127。
  fa852c1 已修。修后自检：round≥2 的 runlog 应出现
  `mt49: external task=0x...`；若仍 127 再报我。
- 顺手改进：单发 20-40% ⇒ 3 轮累计仅 49-78%。已把 STAGE-R / STAGE-C 各提到
  **4 轮**（累计 59-87%），每轮独立进程，不破"一进程一写"纪律。总预算
  R0(≤3)+ENF(≤3)+R(≤4)+C(≤4)≈18min，与历史 boot 预算同量级。

## 五、对 MT49_ADJUDICATION 的修正声明

§二"attempt 2 的 rb_insert rebalance 旋转把树指针写进 task+0x770..0x788"
一句**作废**：pstore 证明崩溃发生在 insert 之前的 leftmost→lock 断言，
rotation 写坏 cred 指针的推演从未被到达。根因定罪（同进程二触 + v37_*
静态词不清 + 毒树）与修复（一进程一写，RETRY=1）**不变且被 pstore 反向加强**。
已在该文档顶部加勘误横幅。

## 六、执行指令（重启后）

1. 重建 .so → `preload_mt49.so`（main.c 自 4b5ff7e 未再动，无新增编译风险点）
2. `test_mt49_root.sh`（已带 4 轮改动）全套：R0 → ENF → STAGE-R(×4) → STAGE-C(×4)
3. 里程碑判读不变：`STAGE-R LANDED`（CapEff 满帽）→ `ROOT-ALIVE` → `KSU-LOADED`
4. 若 STAGE-C 后 root_alive 出现而 ksu 未成：Enforcing 下 finit_module 走
   kernel SID 一线，或再补一轮 ENF —— root_alive 本身已是路线成立

## 七、附：冷却假说（COOLDOWN_HYPOTHESIS）意见

实验设计好，**批准做**（等 20-30min 不重启再判活，正好是受控变量：同 boot
同 .so 只变时间）。两点补充：

1. **机制另有候选**："重启后立刻跑就灭" 与 slab 关系存疑 —— 重启本身会把 slab
   全部重置成干净态，"新鲜 boot 的 slab" 理论上更有利而非更差。更贴数据的
   机制是**系统安静度**：刚重启时 zygote/应用初始化/trm 抖动大，race 窗口
   （pselect+核绑定）被调度噪声打烂；停手 30-40min 后系统静默 → 窗口可达。
   两个机制的操作结论相同（灭→先等再试，别急着重启），但可以用对照区分：
   再判活前记 `/proc/loadavg` + 当前 CPU 频率，若"等后活"总伴随低负载，
   坐实安静度假说。
2. **注意混淆变量**：表里 4 个 ✅ 行全都同时换了 .so/代码（09:52 P0-A、
   11:29 mt47、13:15 mt48），"等待"与"改代码"共线。1f3bc1bf 上这个不动代码
   纯等待实验正好补上这个洞 —— 这也是它值得跑的原因。

若冷却成立：R0 灭 → 等 20-30min → 再判活 → 仍灭才重启。省设备，也省 boot
预算。这与 mt49 无冲突，纯判活策略优化。

—— 外部评审（这次连断言簇的六个入口都给你数完了）
