# ★★★ 源码级崩溃机制确认: 5.10 写 task->cred = init_cred 必崩的原因 (2026-08-15 19:0x)

## 崩溃点 (kernel/cred.c 源码铁证)
__put_cred() (cred.c:134-148):
  BUG_ON(atomic_read(&cred->usage) != 0);      // init_cred usage 是全局共享计数
  BUG_ON(cred == current->cred);                // 进程退出时 put 自己的 cred
  BUG_ON(cred == current->real_cred);

put_cred_rcu() (cred.c:111-113):
  if (atomic_read(&cred->usage) != 0) panic(...)  // usage != 0 也 panic

## 崩溃机制
1. 我们写 task->cred = init_cred (共享全局 cred, usage 被很多线程引用)
2. 进程退出 → exit_creds() → put_cred(init_cred) → usage-- 
3. 若 usage 减到 0 → __put_cred → BUG_ON(usage != 0) 或 BUG_ON(cred == current->cred) → PANIC
4. 或 put_cred_rcu → usage != 0 panic

## 为什么 ghostlock 6.12 不崩
6.12 的 cred 生命周期检查不同 (移除/改了这些 BUG_ON), 或 init_cred 处理不同

## 正本清源结论
- TASK_CRED_OFF=0x780 正确 (反汇编铁证)
- 写链 (PSELECT_W) 正确 (已修)
- **但"写 task->cred = init_cred"在 5.10 必崩 (cred 生命周期)**
- 不是偏移/写链 bug, 是 5.10 的 cred 生命周期检查

## 解法方向 (有据可依)
1. 写 real_cred + cred 两个指针 (exit_creds 对两个都 put_cred)
2. 不能指向共享 init_cred → 需要新分配 usage=1 的 cred 副本 (喷页假 cred 但 usage 字段要对)
3. ★ 改 cred 内容 (uid/caps 字段) 不改指针 → 进程退出 put 自己的 cred, usage 正常, 不崩
   - 但需要知道 task->cred 指向哪 (无读原语, 难)
4. ★ 写 task->real_cred 和 cred 都指向"喷页上 usage=1 的假 cred" (mt28 假 cred 思路 + usage 修正)
   - mt28 假 cred 崩是因为 usage=0x100 或字段错, 修正 usage=1 + 完整字段可能不崩

