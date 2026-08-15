# FUSION: Page Reuse (V+R 系列融合)

## 日期
2026-07-16

## 核心问题

R8_test4 证明 pselect 写原语**首次成功触发**:
```
phase6 leaked=ffffff80734be180    ← mm_struct 泄漏成功
prepare: OK base=ffffff80734b8000 ← kernel page 准备成功
direct-w64[0] target=ffffff80028a77d0 value=ffffffc00a78a590  ← 写原语触发
→ 日志截断, 内核崩溃, 手机重启
```

但 `run_direct_root_stage` 需要 4-5 次写操作:
1. 读 per_cpu_offset (shape=0, 写 boot_id 再读回)
2. 读 entry_task (shape=0)
3. 写 real_cred = init_cred (shape=1)
4. 写 cred = init_cred (shape=1)
5. 写 SELinux_ENFORCING = 0 (shape=1, followup)

**每次写操作都在子进程内重新调用 `prepare_good_kernel_page`**:
- prepare_ctx: 272 个 clone_memfd
- spray_ctx: 204 个 clone_memfd
- pre_ctx: 33 个 + post_ctx: 34 个
- 合计 ~543 次进程创建/销毁 + heap spray + SKB reclaim

**总计 ~2700+ 次进程创建**。MTK 5.10 slab 在第一次 543 clone 后就不稳定,后续完全不可能存活。

## 融合思路: Page Reuse

### 关键洞察

kernel page 提供的是**基础设施** (fake_lock / fake_w0 / fake_task), 这些对所有写操作都相同。
**每次写的 target/value 来自 pselect fd_set (用户态栈)**, 不来自 kernel page payload。

因此: 一次准备 kernel page, 可以为所有 4-5 次写操作复用。

### 代码变更

#### 1. common.h
- 新增 `extern int page_reuse_active;` 全局标志

#### 2. main.c — `run_direct_root_stage`
- 在写操作序列**之前**, 父进程调用 `prepare_good_kernel_page(PAGE_PAYLOAD_SLIDE)` 一次
- 成功后设 `page_reuse_active = 1`
- 所有 4-5 次写操作复用同一 kernel page
- 写操作完成后设 `page_reuse_active = 0`
- 如果 page 准备失败, 回退到原始模式 (每次写各自准备)

#### 3. pipe.c — `direct_pselect_write_once_internal`
- 子进程检查 `page_reuse_active`:
  - **reuse=0** (原始): 清零全局变量 → `prepare_good_kernel_page` → `prepare_skb_payload` 验证
  - **reuse=1** (融合): 跳过全部准备, 验证 `page_base`/`fake_lock`/`fake_w0`/`fake_task` 非零 (从父进程 fork 继承)
- 超时: reuse 模式 60 秒 (vs 原始 180 秒)

#### 4. fops.c — `do_pselect_fake_lock_route`
- retry 循环中检查 `page_reuse_active`:
  - **reuse=0** (原始): 每次重试重新 `prepare_good_kernel_page`
  - **reuse=1** (融合): 重试复用同一 page, 不重新准备

### 为什么安全

1. **kernel page 持久性**: `prepare_good_kernel_page` 成功后, spray_ctx 中 ~199 个 memfd 仍然打开, 钉住 slab page。子进程通过 fork 继承这些 memfd, page 保持 pinned。

2. **payload 不需要更新**: kernel page 的 SKB payload (SLIDE mode) 提供 fake_lock/fake_w0/fake_task 基础设施。原始代码中的 `prepare_skb_payload(PAGE_PAYLOAD_FOPS)` 只更新用户态 `skb_buf`, **从不重新发送到内核**。kernel page 始终保持 SLIDE payload。

3. **per-write target/value 在 fd_set**: `prepare_pselect_fdsets` 从 `pselect_custom_target`/`pselect_custom_value` 构建 fd_set, 这些是用户态变量, 每次写操作前由 `set_pselect_write` 设置。fd_set 在 pselect 栈上, rb_erase 操作的对象就是这个 fd_set waiter。

4. **followup 写也复用**: `direct_pselect_write_once_internal` 中的 followup 递归调用 `direct_pselect_write_once`, 同样检查 `page_reuse_active` 并复用 page。

### Clone 数量对比

| 模式 | 写操作 1 | 写操作 2 | 写操作 3 | 写操作 4 (followup) | 总计 |
|------|---------|---------|---------|---------------------|------|
| 原始 R8 | 543 | 543 | 543 | 543+543=1086 | **~2715** |
| 融合 | 543 (父进程) | 0 | 0 | 0 | **~543** |

### 潜在风险

1. **PI chain 腐败累积**: 每次 pselect 写原语通过 GhostLock PI chain 竞态在内核 rt_mutex 树中留下损坏的 waiter 指针。4-5 次写操作会累积 4-5 个损坏指针, 内核可能在后续调度时 panic。
   - R8_test4 在第一次写后崩溃, 表明崩溃可能在 pselect race 期间发生
   - 融合减少了 clone 压力, 但不解决 PI chain 腐败问题
   - 如果写操作足够快 (无 543 clone 延迟), 可能在内核 panic 前完成全部写操作

2. **kernel page 被回收**: 如果内核在写操作之间回收了 slab page, 后续写操作会失败 (子进程 exit code 12)
   - 缓解: spray_ctx memfds 钉住 page, 回收概率低
   - 后续可添加 fallback: 检测到 exit 12 后自动回退到非 reuse 模式

3. **超时**: reuse 模式 60 秒超时应该足够 (pselect + PI chain race 约 5-15 秒, 3 次重试最多 45 秒)

## 测试计划

1. 在 matisse-OS2.0.6.0.ULKCNXM 上构建: `make`
2. 部署到 rish shell (uid=2000)
3. 运行 exploit, 观察日志:
   - `direct-fusion: page prepared OK` → page 准备成功
   - `direct-w64[N] ... reuse=1` → 各次写操作复用 page
   - 如果所有 4-5 次写操作完成 → 检查 `direct-root-summary`
4. 如果在第 2 次写后崩溃: 说明 PI chain 腐败是主要瓶颈, 需要进一步研究:
   - 减少写操作次数 (合并步骤)
   - 在写操作之间修复 rt_mutex 状态
   - 研究单次 pselect 写完成全部 cred 覆写的可能性

## 文件变更清单

| 文件 | 变更 |
|------|------|
| `src/common.h` | +1 行: `extern int page_reuse_active;` |
| `src/main.c` | +20 行: page 准备 + reuse 标志 + 错误路径清理 |
| `src/pipe.c` | +15 行: reuse 分支 + 动态超时 |
| `src/fops.c` | +1 字: `&& !page_reuse_active` 条件 |

## 下一步

- [ ] 在设备上测试融合版本
- [ ] 如果首次写成功但后续崩溃: 研究 PI chain 腐败修复
- [ ] 如果 page 被回收: 添加 fallback 到非 reuse 模式
- [ ] 考虑将步骤 3+4 (cred 写) 合并为单次 pselect (减少 PI chain 腐败次数)
