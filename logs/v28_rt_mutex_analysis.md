# rt_mutex_adjust_prio_chain 分析 (2026-07-15)

## 三个 rb_erase 调用点

| # | 地址 | 节点(x0) | 树根(x1) | 用途 |
|---|------|---------|----------|------|
| 1 | 0x1eb328 | x28=top_waiter | lock->waiters+0x8 | 从waiters树删tree_entry |
| 2 | 0x1eb8f8 | x24=adjust_waiter | lock+0x880 (pi_tree) | 从pi_tree删 (可能是tree_entry) |
| 3 | 0x1ebedc | x24=adjust_waiter | lock+0x880 (pi_tree) | 从pi_tree删 (可能是pi_tree_entry!) |

## 关键检查 (Call 3 前面的门禁)

Call 1 前: waiter->lock==current_lock (0x1eaf2c-34) — b.ne→bail
Call 2 前: compare+leftmost_search → 条件性跳过
Call 3 前: 同类检查 — 可能在Call2和Call3之间的循环中bail

## 假设
- Call 1/2 用 tree_entry (=OFF|RED) → 写 name_ptr → 已知触发
- Call 3 用 pi_tree_entry (=FOPS-8|RED) → 写 FOPS → 未触发!
- Call 3 未触发原因: rt_mutex_adjust_prio_chain 中间检查失败,
  可能在 Call 2 的 corrupt write 后内核状态不一致导致提前bail

## 下一步实验
- 用PSELECT_WPC/WRIGHT/WLEFT env vars控制pi_tree_entry值
- 验证env vars是否生效
- 尝试让Call 3更容易通过检查
