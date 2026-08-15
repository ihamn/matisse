# ★★★ 历史 shift 结论修正 (2026-08-15 23:1x)

## 关键发现 (查 v/R/mt 全系列历史)
1. **mt16 (8-14 20:1x)**: shift 0-7 全扫, 全部 bootid_changed=0
   - 但这是"旧触发" (sched 触发, walk 不执行) - mt22 修复之前!
2. **mt22 (8-15 02:2x)**: 修复触发 = consumer 补发 futex_lock_pi(f_pi_target, 50ms)
   -> 写原语成立 (boot_id 被改写)
3. **mt22 后所有版本 (mt26/29/40/44) 都用 shift=0** (没重扫)
   - mt26 成功 = shift=0 恰好对该 boot 布局 (运气)

## 结论 (修正)
"mt22 修复触发后的 shift 0-7 扫描"从未做过 - mt16 的扫描前提已失效
= 真·未试维度 (但不是"从没扫过", 是"修复后没重扫")

## fresh_eyes_review 约束
shift 8-15 结构性无效 (15-word 窗口数学) -> 只扫 0-7

## 下一步
用 mt44+ (含 mt22 futex 触发 + cred_cand 写链) 扫 shift 0-7:
- OBS_ONLY 观察: futex trigger 是否从 110 变成命中 (walk 读到假 waiter)
- 命中 shift -> 该 shift 跑写验证 (uid 变化)

