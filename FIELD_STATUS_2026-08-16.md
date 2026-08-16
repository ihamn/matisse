# 现场现状 — 连续 boot 判活失败, 请审视 (2026-08-16)

> 状态：设备 boot 13c15d67 判活 3 轮灭，脚本已按纪律退出。
> 但我们发现失败模式**变了**，想请您审视后再决定跑/换。

## 最新 R0 RUNLOG（boot 13c15d67）
```
prepare_kernel_page: done
mt19: SLIDE page prepared base=0xffffff82d0968000   ← prepare 完全正常
mt22: trigger attempt 1/1
mt25: futex trigger 0-5 errno=110                    ← 触发链正常
mt22: done wrote=0                                   ← 但写没落地
```

## 模式变化（重要）
- **之前失败的 boot**（e3c8db02/df92cbe2）：prepare 阶段 EACCES 崩（SYSCHK Permission denied）
- **现在失败的 boot**（1f3bc1bf/13c15d67）：prepare 正常 + 触发正常 + **wrote=0**（纯粹没写中）

## 时间线（判活结果）
- df92cbe2: ✅ 活 (mt47/mt48 成功)
- 704bd84c: ✅ 活
- a10e6984: ✅ 活
- 1f3bc1bf: ❌ 3轮灭 (冷却后再测仍灭)
- 13c15d67: ❌ 3轮灭 (prepare 正常, wrote=0)

## 请您审视
1. "prepare 正常 + 触发正常 + wrote=0" 是纯命中率波动（20-40%/轮, 3轮灭≈21%），
   还是系统进入"低活性期"的信号（有什么持久状态在变差）？
2. 连续 boot 判活失败前，系统经历了大量 fork/spray + 多次崩溃重启 ——
   这些是否改变了什么（slab 状态/内存碎片/某内核模块状态）？
3. 我们该：继续换 boot 跑（若纯波动）？还是等一段时间（冷却）？还是改策略？
4. 您分析 bug 簇有新发现吗？是否影响 mt49 跑法？

## 设备状态
- boot 13c15d67, Shizuku 可用, mt49 全套已部署
- 未继续跑（等审视）

—— matisse 现场
