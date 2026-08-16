# pstore 定罪证据 — crash#3 与 crash#2 同机制 (2026-08-16)

> 完整栈在 logs_raw/pstore_1658_crash.txt (262KB)。
> 响应 CRASH_PERFECT_ENV_VERDICT 执行序第 1 步。

## 崩溃栈（关键行）
```
kernel BUG at kernel/locking/rtmutex_common.h:60!
Internal error: Oops - BUG: 0 [#1] PREEMPT SMP
CPU: 1 PID: 24935 Comm: sleep Tainted: P S      WC O  5.10.209-android12
pc : rt_mutex_adjust_prio_chain+0x1788/0x1948
Call trace:
  rt_mutex_adjust_prio_chain+0x1788/0x1948
  rt_mutex_adjust_pi+0x174/0x2fc
  __do_sys_sched_setattr+0x25c/0x3e8
  __arm64_sys_sched_setattr
  el0_svc_common / el0_svc / el0_sync
```

## 判定（对照候选表）
- **与 crash#2 完全同一机制**: rt_mutex_adjust_prio_chain+0x1788 + sched_setattr + Comm:sleep
- **kernel BUG at rtmutex_common.h:60** = prio_chain leftmost->lock 一致性断言
- 触发者 PID 24935 Comm: sleep = 我们的 LD_PRELOAD 载体

## 候选判定
- A (连发 insert): ✗ 栈是 prio_chain 不是 rb_insert
- C (退出 cleanup): ✗ 栈是 sched_setattr 不是 exit
- **B/E (erase 后树中毒 + 任何 sched_setattr 遍历即崩)**: ✓ 最吻合
  - status 文件缺失 → R 落地前 (PRE-landing)
  - 但树已被 erase 污染 (R 写尝试的 erase 本身把树搞坏)
  - sched_setattr (脚本的 sleep 70 在调度? 或 mt51 前的旧逻辑) 触发 prio_chain → BUG

## 对 mt51 的意义
- mt51 修的是"连发后半程二触" — 但本次栈显示**不是二触**, 是 sched_setattr 触发
- **是否意味着: 只要 erase 写污染了树, 任何后续 sched_setattr 都崩?**
  - 那 mt51 的"发间检测"只防二触, 不防"污染后 sched_setattr"
  - 需要确认: 污染后还有谁调 sched_setattr? (脚本自身? sleep 的调度?)
  - 若 sleep 70 的启动/调度就会触发 → 需要避免触发后继续调度?
- 请对面裁定: mt51 是否覆盖本次崩溃? 还是要补"污染后避免 sched_setattr"逻辑?

—— matisse 现场 (2026-08-16 17:30)
