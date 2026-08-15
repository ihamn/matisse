# CHECKPOINT FINAL — v30→v36 全路线回顾 (2026-07-16)

## 证实的事实
1. **deep PI chain 架构稳定** ✅ — 6次测试(v30/v34/v35/v36)，手机从未崩溃
2. **rb_erase parent 触发条件极苛刻** — 仅 OFF (0xffffff80028e76d8) 能触发
   FOPS-8距OFF仅8字节也不能。这是内核rb-tree实现的硬限制，与架构无关。
3. **FOPS覆写死路** ✅ — v30判断正确
4. **R8的bootid_data "成功"可能是误读** — calls=1≠rb_erase执行

## 全部测试数据
| 版本 | parent | ret | calls/success | rb_erase | 手机 |
|------|--------|-----|---------------|----------|------|
| v30 | OFF|RED | 193 | 1/1 | ✅→name_ptr | 正常 |
| v34 | selinux-8|RED | 72 | 1/1 | ❌ | 正常 |
| v35 | FOPS-8|RED | 1 | 1/1 | ❌ | 正常 |
| v36 | bootid-8|RED | 1 | 1/1 | ❌ | 正常 |

## 路线评估
- v系列 (v1-v30): rb_erase→FOPS ❌ csel永远写name_ptr
- R系列 (R1-R11): GhostLock直写 ❌ 无deep chain→崩
- v31-v33: poplicle fork ❌ word映射错+无deep chain
- v34-v36: deep chain+shape=1 ❌ 仅OFF触发rb_erase

## 留存资产
- deep PI chain架构 (稳定不崩)
- shape=1框架 (正确word映射)
- canon_addr修复 (P0_DATA_ALIAS_CONST)
- pselect_custom_target/value/shape体系
- OFF|RED = 唯一确认能触发rb_erase的parent
