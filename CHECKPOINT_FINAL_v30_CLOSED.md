# 🏁 CVE-2026-43499 matisse — 阶段关闭 2026-07-15

## 决策: 放弃 GhostLock rb_erase → fops 覆写路线

### 不可逾越的障碍
rb_erase csel: `if parent->rb_left == node → write rb_left else → write rb_right`

parent 是内核地址时 parent->rb_left 包含内核数据 ≠ 我们的 node(栈/sprayed页地址)
→ csel 永远选 rb_right → parent+0x08=name_ptr，永远写不到 parent+0x10=fops

### 版本历程
v1-v8:  基础架构      v17-v22: sprayed假树(已证废)
v9-v16: pselect线程    v23-v27: split-parent(无Call3)
v28:    Path C原型    v29:     深度PI链
v30:    两层successor + comm验证 → FOPS始终=0 → 终结

### 留存资产
- 完整 heap spray 框架 (kernelsnitch + pipe)
- matisse 全量内核偏移量 (target.h)
- rb_erase + rt_mutex 完整反汇编
- 30 个版本二进制 + 测试日志
- trigger.c (新POC, EDEADLK UAF路径)

### 新方向
trigger.c: 干净 UAF → pi_blocked_on 悬空 → PI chain walk
非 rb_erase 写入 (task struct 更新) 可能是替代原语
待日后有新思路继续
