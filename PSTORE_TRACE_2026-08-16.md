# pstore 崩溃栈捕获 — 崩在 rt_mutex_adjust_prio_chain, 触发者 sched_setattr (2026-08-16)

> 意外收获：mt49 脚本的 pstore tail 功能抓到了**历史崩溃栈**（本次 boot 未崩，
> 是 crash#2 残留）。这正好补上 mt48 定罪时缺的 pstore 证据。

## 崩溃栈（完整）

```
CPU: 1 PID: 28091 Comm: sleep Tainted: P S      WC O  5.10.209-android12
Call trace:
  dump_backtrace → dump_stack → mrdump_common_die → ipanic_die → die
  → bug_handler → brk_handler → do_debug_exception → el1_dbg
  → rt_mutex_adjust_prio_chain+0x1788/0x1948    ← ★ 崩溃点
  → rt_mutex_adjust_pi+0x174/0x2fc
  → __sched_setscheduler+0xedc/0x1558           ← ★ 触发者
  → __do_sys_sched_setattr+0x25c/0x3e8
  → __arm64_sys_sched_setattr
```

栈内存（关键证据）:
```
bc30: 36290778 ffffff82 027b0ae0 ffffff80 ...   ← task+0x778 (0xffffff8236290778) 和 init_cred (0xffffff80027b0ae0) 都在栈上!
bc50: 0279bec0 ffffff80                          ← init_task
```

## 关键事实

1. **崩溃在 rt_mutex_adjust_prio_chain**（偏移 0x1788/0x1948）— 不是您猜的
   rb_insert rebalance，也不是 commit_creds BUG_ON
2. **触发者是 sched_setattr** — 不是子进程 poll。某进程（Comm: sleep, 可能是
   脚本 sleep 或 am kill-all 的进程）调 sched_setattr → __sched_setscheduler →
   rt_mutex_adjust_pi → prio_chain 遍历 → 碰到被污染的 PI 链 → BUG(brk#0x800)
3. **栈上可见我们的写值**（task+0x778 + init_cred）→ 确认是 PTR 写后的崩溃
4. PID 28091 Comm: sleep — 可能是某个 sleep 进程在 sched_setattr 时崩

## 与 mt49 假设的关系

您 mt49 猜的机制是"attempt 2 的 rb_insert 在中毒树 rebalance 旋转写坏
task+0x770..0x788"。但实际栈显示**崩溃在 prio_chain 调整**（不是 rb 操作）。
两种可能：
a. 崩溃链不同：PI 链被污染 → 任何 sched_setattr/pi_adjust 都触发 prio_chain BUG
   （不是 rb_insert 的错）
b. 您的机制对，但最终崩溃表现为 prio_chain（rb 写坏 task 字段后 → prio_chain 遍历
   到坏指针 → BUG）

## 请求裁定

1. rt_mutex_adjust_prio_chain+0x1788 是什么检查？（BUG_ON? 解引用?）反汇编确认
2. sched_setattr 触发链里，为什么 sleep 进程会走 rt_mutex_adjust_pi？
   （sched_setscheduler 对 PI 锁持有者调整优先级 → prio_chain → 我们的假 waiter 在链上?）
3. 这对 mt49（一进程一写）有影响吗？还是 mt49 的 RETRY=1 已经规避了？
4. 当前 STAGE-R 3 轮未落地（CapEff 空）是触发未中还是别的问题？
   round 2/3 rc=127 (PSELECT_TASK 外部模式可能未实现/报错)

## 设备状态
- boot a10e6984 未变（本次没崩，pstore 是残留）
- STAGE-R 3 轮未落地 → 脚本已退（按您的"换 boot"逻辑）
- mt49 .so + 脚本已部署

—— matisse 现场 (2026-08-16 14:10)
