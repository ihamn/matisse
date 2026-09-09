# 野指针根治: mt86 UNPOISON (2026-09-09)

## 根因 (CVE-2026-43499 官方描述 + 5.10 源码实证)
- kernel/locking/rtmutex.c:1066 `remove_waiter()`:
    raw_spin_lock(&current->pi_lock);
    rt_mutex_dequeue(lock, waiter);
    current->pi_blocked_on = NULL;      ← 用 current, 不是 waiter->task
- 在 proxy-lock 回滚路径 (futex_requeue → rt_mutex_start_proxy_lock) 里,
  current = 发起 requeue 的线程, waiter = 被 requeue 的线程 →
  **真正阻塞的那个线程的 pi_blocked_on 悬垂**, 指向已释放的 rt_waiter
  (它落在已被 pselect fd_set 覆写/回收的内核栈上).
- rtmutex.c:507 `rt_mutex_adjust_prio_chain()` 第一句就是
  `waiter = task->pi_blocked_on;` → 之后每一次 PI 操作 (sched_setattr /
  futex / 优先级传播) 都会遍历这个悬垂节点 → 随机内核写 (事故报告实证).

## 为什么毒一直活着
exploit 的 slide_waiter_thread 写完 pselect 后是 `for(;;) sleep(1);` —
**该线程永不退出** → 悬垂 pi_blocked_on 一直挂在一个活任务上, 直到进程被杀.
这解释了事故报告里 "child 存活数小时, 任何 sched_setattr/futex 都触碰毒链".

## 修复 (mt86)
slide_waiter_thread 在 pselect 写完成之后, 再做一次**干净的 PI 阻塞**:
  FUTEX_LOCK_PI(f_pi_target)   ← owner 一直持有它 → 真阻塞
  → rtmutex.c:962 `task->pi_blocked_on = waiter;` **覆盖悬垂指针** (先于任何 walk)
  → owner 收到旗子后 FUTEX_UNLOCK_PI(target)
  → waiter 侧 remove_waiter() 这次 current == waiter, 正确清空 pi_blocked_on
  → waiter 再 UNLOCK_PI(target) 收尾
不新增任何写原语; 关闭开关 `PSELECT_NO_UNPOISON=1` (A/B 对照).

## 产物与复现
- ~/matisse/bin/mt86/preload.so  sha256 47448a90580973f03affbc1f5ba177f8ac1c6fa9a1d1a1f3f97e5c159816c6c6
- 构建: cp workspace src → ~/mt86_build, `make preload PROJECT=matisse-OS2.0.6.0.ULKCNXM CC=clang`
  (Termux 原生 clang, 无需 NDK; **未改源码时复现 mt85 的 sha 893e0ad7** = 构建管线可信)
- 判据日志: "mt86b: UNPOISON lock_pi(target) ret=0" + "mt86b: owner UNPOISON unlock"

## 待验证 (需设备)
1. unpoison 的 LOCK_PI 是否真的阻塞 (ret=0) 而不是 EDEADLK/EAGAIN
2. 之后是否还出现随机涂抹类崩溃/设置重置 (A/B: PSELECT_NO_UNPOISON=1)
3. 若 unpoison 自身引发 panic, pstore 会记录在 remove_waiter / adjust_prio_chain 附近
