# v30 完整状态总结 — 2026-07-15

## 已验证事实

### rb_erase 调用次数
- rt_mutex_adjust_prio_chain 里只有 **2次** rb_erase
- Call 1: lock->waiters (tree_entry, parent=OFF|RED) → 写 name_ptr
- Call 2: task->pi_waiters (tree_entry, parent=OFF|RED) → 写 name_ptr
- **没有 Call 3！pi_tree_entry 从未被 rb_erase**

### OFF 特殊性
- 只有 OFF|RED 产生强触发 (ret=150-199)
- FOPS-8、FOPS、init_task.comm-8 全部 ret=1
- 推测: cascade 需要内核在 PI walk 期间访问 name_ptr

### 写入能力
- 只有 8 字节写入 name_ptr (OFF+8)
- 写到 sprayed page 地址
- name_ptr 是字符串指针，无直接利用

### 死路
1. Path C → MTK 定制 rb_erase
2. Deep PI chain → 无额外 rb_erase
3. 方向 B → Call 3 不存在
4. configfs → 必须 fops 覆写
5. pipe physrw → 依赖 cfi_stage

## 待探索
- 用 name_ptr 写入触发其他内核行为
- 完全不同的 fops 覆写方法
- 不依赖 fops 的提权路径
