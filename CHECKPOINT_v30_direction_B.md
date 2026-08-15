# v30 方向 B: 绕过 lock 回指验证 — 2026-07-15

## 目标
让 Call 3 (pi_tree_entry rb_erase, parent=FOPS-8|RED) 执行
→ 写 fake_fops 到 ASHMEM_MISC_FOPS → 赢得一切

## 卡点
rt_mutex_adjust_prio_chain 里:
```
ldr x8, [x28, #0x38]  // waiter->lock
cmp x24, x8
b.ne out              // waiter->lock != current_lock → 退出
```
out[2] (waiter->lock) = fake_lock (sprayed page addr)
current_lock = f_pi_target 的 rt_mutex 内核地址 (未知)

## 方案
将 rt_mutex (pi_state->pi_mutex) 分配到我们喷的页面上
→ rt_mutex 地址 = sprayed page 地址 = fake_lock → 匹配!

## 关键
- pi_state 从 futex_cache slab 分配
- 当前 spray 可能不覆盖 futex_cache
- 需要: 检查/扩展 spray 到 futex_cache

## 当前状态
- SLIDE: ✅ (slide=0, KASLR disabled)
- GhostLock type confusion: ✅ (ret=150-199)
- Deep PI chain: ✅
- Path C: ❌ (MTK 定制, 死路)
- Call 3: 未执行 (lock check 失败)
- FOPS: 始终 0
