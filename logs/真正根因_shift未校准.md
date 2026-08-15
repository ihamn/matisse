# ★★★ 真正的研究结论: futex trigger 110 根因 = shift 未校准 (2026-08-15 23:0x)

## 核心发现 (读 ghostlock README + 对比)
1. ghostlock README: "waiter word + 11 <= 14, max feasible waiter word = 3"
   - 假 waiter 必须落在 fd_set 可控区 (word 0-3), 否则 overlay 无效
2. ghostlock README: "waiter position determined by compiler (PGO+LTO), not kernel version"
   - 不同内核 waiter 栈位置不同, 必须用 kprobe 测 PSELECT_SHIFT
3. 我们 mt 系列 shift=0 从没校准 (slide.c:31)
   - mt26 偶尔中 = shift=0 恰好对那个 boot 布局 (运气)
   - mt44 不中 = 布局没对齐 -> walk 读到垃圾 -> futex trigger 110 (不崩不写)

## 为什么绕了这么久
- mt32-44 一直在调 env (WPC/TREE_PC/cred_cand), 没回去读 ghostlock README 的 shift 部分
- 8-14 fresh-eyes 就提过"几何校准", 被我们忽略
- 教训: learn-from-original-projects skill (先读原项目/适配项目)

## 真正瓶颈
**PSELECT_SHIFT 未校准** -> 假 waiter 没落在正确栈位置 -> walk 读不到假 waiter -> 不写

## 下一步 (有依据)
扫 shift 0-7 (8 个值) x OBS_ONLY 观察:
- 哪个 shift 下 futex trigger 不再 110 (walk 命中假 waiter)
- 命中 shift 后 -> 该 shift 下跑写验证
- 零风险 (OBS_ONLY 不写)

