# panic 全机制分析 (2026-09-09 凌晨, pstore 实证)

## 崩溃签名
rt_mutex_adjust_prio_chain+0x188 解引用 0x1 (kernel_panic → 重启)
寄存器: x19=0xffffff825aa8ca00 (walk 中的 waiter 节点), x8=0x1 (从节点
读出的坏指针 = fd_set 位值), x22/x17/x24=0xffffffd1f6b9f000 区间
= **kernelsu_gki209.ko 模块内存** → finit_module 已成功, 模块已加载!

## 完整因果链 (三层)
1. fdset overlay 毒化 freed rt_waiter: 10 词中我们只植 3 词
   (tree_pc/right/left), 其余 = fd_set 位图残值 (小整数如 0x1)
2. 模块加载成功后, 任何任务的 PI 操作 → adjust_prio_chain walk
   → 经由 task->pi_blocked_on (悬垂毒节点) → 读出 0x1 指针 → 解引用 → panic
3. panic 时 /data 有在途写 → 日志回放损坏 → IME/设置重置 (第二次)

## 修复方向 (精确, 非抽奖)
fd_set overlay 必须种植**完整合法 waiter** (ghostlock 6.12 的干净树设计):
- 未被几何使用的 fd_set 词 → 预填合法内核指针 (指向安全锚节点的
  list_head, 使 walk 遍历到它们时读写皆安全)
- slide.c prepare_slide_pselect_fdsets 的补丁点
- 这消除了 panic 的根因 (毒词), 而不是回避其症状

## 与既有证据的一致性
- 4 份 panic 偏移 (+0x188/+0x1d8/+0x9fc/+0x1788) = walk 不同阶段
  碰到不同毒词的形态
- "内核堆地址 x19 正常但字段=0x1" = walk 从毒节点读字段而非节点本身坏
- finit_module 成功 = 模块加载器/vermagic/符号全部工作 ✓ (L2 第一关过)
