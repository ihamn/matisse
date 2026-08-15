# BREAKING: rt_mutex_adjust_prio_chain 只有 2 次 rb_erase！

## 反汇编确认
Call 1 @ 0xffffffc0081eb328: rb_erase(&waiter->tree_entry, &lock->waiters)
  → 写 OFF+8 = name_ptr

Call 2 @ 0xffffffc0081eb8f8: rb_erase(&waiter->tree_entry, &task->pi_waiters)
  → 同样写 OFF+8 = name_ptr !!!

## 没有 Call 3！
- pi_tree_entry 从未被 rb_erase
- split-parent (pi_parent=FOPS-8|RED) 从未被使用
- 所有之前基于"3次 rb_erase"的分析和方向 B 都基于错误假设

## 含义
- GhostLock rb_erase 永远只能写 name_ptr (OFF+8)
- FOPS 无法通过 rb_erase 覆写
- 需要完全不同的 FOPS 覆写方案
