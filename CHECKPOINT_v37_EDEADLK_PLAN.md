# CHECKPOINT v37 — EDEADLK 路径重启计划 (2026-07-16 晚)

## 路线切换逻辑

### 从 v 系列日志中发现的真相

| 版本 | 路径 | EDEADLK? | 结果 |
|------|------|----------|------|
| v8 | EDEADLK + pselect | ✅ errno=35 | pselect崩 |
| v10 | EDEADLK(wake=0) | ❌ errno=22 | pselect fallback |
| v13+ | deep chain (FUTEX_LOCK_PI) | ❌ 放弃EDEADLK | 稳定但FOPS=0 |
| v23_11 | deep chain | ❌ | ret=161最强触发 |
| v30 | deep chain | ❌ | 确认rb_erase死路 |
| v34-v36 | deep chain+shape=1 | ❌ | 仅OFF触发rb_erase |

### 关键发现
- **v8是唯一用过EDEADLK的版本** — 触发成功但误用pselect崩了
- **后续全部版本都放弃了EDEADLK** — 转deep chain
- **原始PoC (poc.c+trigger.c) 的完整路线从未被尝试**:
  EDEADLK → stamps填充栈 → sched_setattr → PI chain walk读stamp→类型混淆
  这条路线**不走pselect，不走rb_erase**！

### EDEADLK路线理论优势
- PI chain walk直接读pi_blocked_on→stamp数据，不需要rb_erase
- 没有parent地址限制
- 可能直接修改kernel状态（task->prio、lock->owner等）

### v系列可复用资产
1. prepare_kernel_page (heap spray + Kernelsnitch) — 可替代stamp栈填充
2. shape=1 fd_set配置逻辑
3. canon_addr修复
4. OFF|RED触发条件知识
5. 正确的rt_mutex_waiter word映射

### 下一步
- 编译trigger.c验证EDEADLK仍然可用
- 若成功，移植stamps机制
- 最小化改动，逐步验证
