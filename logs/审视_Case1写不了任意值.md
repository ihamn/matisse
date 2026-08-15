# Fresh-Eyes 审视: mt44 失败机制根因 = Case-1 写不了任意值 (2026-08-15 23:3x)

## 发现 (一手证据, mt26 成功机制)
mt26 成功机制 (kallsyms_verified):
- Case-1 主树写: TREE_PC=enforcing-8, TREE_LEFT=0
- 写 parent->rb_right (=tree_pc+8 = enforcing)
- **值 = tree_pc & ~0xff (低字节恒 0)** - 不是 WRIGHT!
- enforcing byte0=0 -> Permissive (目标低字节恰好是布尔, 写0有效)

## 关键问题: mt44 写 cred+0x4
- 我们设 WRIGHT=0, 但 Case-1 忽略 WRIGHT!
- 实际写值 = tree_pc&~0xff = (cred-4)&~0xff = cred 页对齐地址 (非0)
- **即使写中, uid 也不会变 0** (写的是页地址低字节, 不是0)

## 审视结论
1. mt44 用 Case-1 写 cred+0x4 是机制错误:
   - Case-1 写不了任意 0 值, 只能写 tree_pc 派生值
   - cred+0x4 (uid=2000) 不是"写0有意义"的目标 (需要精确写0)
2. 写 enforcing 成功 = 目标低字节是布尔 (0/1), 写页对齐值恰好=0
3. boot_id 成功 = 目标区域被写坏 (值无所谓, 只要变)

## 正确的方向
- Case-1 只适合"写页对齐值/写0到布尔/写任意变化"的目标
- cred uid 需要精确 0 -> 需要 Case-2 (任意值写) 或 Case-1 的变体
- 或接受: 写 cred 内容的路子, Case-1 做不到精确0

## 教训 (research-before-blind-retry)
- 又没搞清 Case-1 写值机制就试了 mt44
- 该先验证"Case-1 写进目标的值到底是什么"

