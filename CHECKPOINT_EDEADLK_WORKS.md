# CHECKPOINT — EDEADLK 路径验证成功 (2026-07-16 晚)

## 测试结果
- 文件: trigger.c (原始PoC，无修改)
- 二进制: /data/local/tmp/trigger_test SHA256=8f7ba6fd
- 日志: logs/trigger_edeadlk_test5.txt

## 完整链路通过
1. FUTEX_CMP_REQUEUE_PI → errno=35 (EDEADLK) ✅
2. FUTEX_WAIT_REQUEUE_PI → errno=110 (ETIMEDOUT, 栈释放) ✅
3. getpid() thrash — 轻量stamp，非受控
4. FUTEX_LOCK_PI(cycle_futex) → PI chain walk → returned! ✅
5. 手机没崩 ✅

## 对比历史
- v8: EDEADLK成功 → pselect崩 ← pselect是问题，EDEADLK不是
- v10-v36: 全部放弃EDEADLK，改deep chain
- trigger.c: EDEADLK + UAF probe ← 不依赖pselect，不崩

## 下一步: stamps移植
- 替换getpid()为受控stamp (prctl/socket/pselect/process_vm)
- stamp填充: fake rt_mutex_waiter (lock/task/prio/树节点)
- PI chain walk读stamp → 观察修改了什么内核状态
