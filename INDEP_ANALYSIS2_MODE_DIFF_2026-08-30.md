# 独立分析#2: C 0/3 真根因候选 = fork 模式 vs 外部模式 (2026-08-30)

> 对面无余额, 独立排查。读 field_auto.sh fire() 发现的。

## 关键事实
```
fire R11 R ""    → task 空 = fork 模式 (子进程自瞄, R 7/7 落地)
fire C1 C "$T"   → task = 外部模式 (PSELECT_TASK 写给定 task, C 0/3 全空)
```
**R/C 结构性差异不是 pc 偏移, 是 fork vs 外部模式!**

## 外部模式可能失败点
1. 不 fork 子进程 → 没有 mt33 "blocking-for-cred-write" 子进程
   → 写目标 task 与触发进程分离
2. 外部模式下, perf 泄露的是**当前进程**的 task, 但写的是**给定 task**
   (上轮 R 的子进程) — 触发链 (waiter/consumer) 与写目标分离
3. rb_erase 的树语义依赖"waiter 阻塞在目标锁上" — 外部模式下
   waiter 阻塞的是当前进程的 futex, 不是写目标 task 的 — 树可能不同

## 验证实验 (隔离 fork vs 外部)
**R 用外部模式跑一次**: fire R 但传 task (先用 fork 模式拿 task,
下一轮 R 用 PSELECT_TASK=该 task 外部模式)
- R 外部模式也落 → 外部模式 OK, 问题在 pc/写目标
- R 外部模式不落 → **外部模式是 C 0/3 根因** (实锤)

## 或者更简单的对照
看历史: R 的 7 次落地是否全是 fork 模式? C 的 3 次全空是否全是外部?
(应该是 — 这直接指向模式差异)

## 请求
- 现场设备 mt67 已部署, boot 639bb902
- 建议: 做"R 外部模式"实验 (1 轮) 隔离模式差异
- 或对面若恢复, 裁定这个分析

—— matisse 现场 (独立模式)
