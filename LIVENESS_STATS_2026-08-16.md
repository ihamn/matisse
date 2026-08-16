# 判活率 + 失败模式统计表 (2026-08-16 全天)

> 从现场日志 + 实验记录整理。供评审审视"低活性期"是否成立。

## 判活历史（按时间）

| # | boot_id (前8) | 时间 | 判活 | 失败模式 | 备注 |
|---|--------------|------|------|---------|------|
| 1 | 28ca595f | 09:52 | ✅ R0 round2 | — | mt46 P0-A CHILD-ROOT 成功 |
| 2 | df92cbe2 | 11:29 | ✅ | — | mt47 R0 成功→ENF Permissive→PTR 崩#1 |
| 3 | 704bd84c | 13:15 | ✅ round1 | — | mt48 R0 成功→ENF 4轮灭→PTR 崩#2 |
| 4 | a10e6984 | 13:5x | ✅ round1 | — | mt49 R0 成功→ENF 3轮灭→STAGE-R 未落地 |
| 5 | 1f3bc1bf | ~14:00 | ❌ 3轮灭 | prepare 正常, wrote=0 | 冷却后再测仍灭 |
| 6 | 13c15d67 | ~14:5x | ❌ 3轮灭 | prepare 正常, wrote=0 | 当前 boot |

## 失败模式分类

### 模式 A：prepare 阶段 EACCES 崩（早期）
- boot: e3c8db02, df92cbe2 (第一次)
- 特征: SYSCHK(open /proc/pid/mem) Permission denied
- 修复: c 方案 (SCM_RIGHTS 自开 pin) → 已解决

### 模式 B：写落地后崩溃 (PTR 阶段)
- boot: df92cbe2 (crash#1), 704bd84c (crash#2)
- 特征: 写执行瞬间 panic
- 修复: mt48 (commit_creds BUG) + mt49 (prio_chain 二触) → 已定罪

### 模式 C：prepare 正常 + 触发正常 + wrote=0 (当前)
- boot: 1f3bc1bf, 13c15d67
- 特征: memfds opened ✓, SLIDE page prepared ✓, futex trigger 0-5 ✓, wrote=0
- **这是纯命中率问题还是低活性期？** ← 待评审审视

## 关键观察
1. 模式 A/B 都已定罪修复（c 方案 + mt48/mt49），**当前只剩模式 C**
2. 模式 C 的 boot prepare/触发全正常，只是写没中 —— 20-40%/轮, 3轮灭≈21%,
   连续 2 boot 灭≈4.5%, 不算异常但也值得记录
3. 时间相关性: 模式 C 出现于**大量 fork/spray + 多次崩溃重启之后**
   (28ca595f 成功 → 6 boot 消耗, 其中 3 次崩溃重启)
4. 冷却假说 (COOLDOWN_HYPOTHESIS) 在 1f3bc1bf 上未验证成功 (等后仍灭)

## 待评审问题 (见 FIELD_STATUS)
1. 模式 C = 纯波动 or 低活性期？
2. 大量 fork/spray + 崩溃重启是否改变了持久状态？
3. 继续换 boot or 等待 or 改策略？

—— matisse 现场
