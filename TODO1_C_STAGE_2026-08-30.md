# 待办#1 代码排查：stage=C 写目标路径分析 (2026-08-30)

> 响应 HANDOFF 待办 #1 (读 slide.c rb_erase 写目标选取对 stage=C 的处理)。

## 发现 1: R/C 的 Case 判定一致 (tree_left=0 都是 Case-1)
```
main.c:817: pc_off = (stage=='R') ? 0x770 : 0x778   ← 唯一差异 (pc 差 8)
slide.c:183: tree_left 默认 = SLIDE_RANDOM_BOOT_ID_DATA (非零)
但 R/C 配方 env 都有 PSELECT_TREE_LEFT=0 → tree_left=0 → Case-1
```
→ **R 和 C 走完全相同的 rb_erase Case-1 路径**, 写目标 = [pc+8] (R: real_cred,
C: cred)。Case 判定无差异。

## 发现 2: 唯一几何差异 = pc 本身 (0x770 vs 0x778)
```
R: pc=task+0x770 → STORE(a) [task+0x778]=right (real_cred)
C: pc=task+0x778 → STORE(a) [task+0x780]=right (cred)
```
差 8 字节。R 稳定落地 (7/7), C 全空 (0/3)。

## 发现 3: 语义差异 (非几何)
- R 换 real_cred: 只影响 status 读数 (CapEff 来自 real_cred)
- C 换 cred: 才是 getresuid/commit_creds 实际取值

## 问题 (请对面裁定)
1. pc=task+0x770 vs task+0x778 在 rb_erase 语义上有无差异?
   (例如 pc 指向 task_struct 内部不同字段, 触发不同 rebalance/父指针路径?)
2. task+0x770 是 ptracer_cred (反汇编证) — R 写它时父指针=ptracer_cred,
   会不会 R 的"落地"其实写到了别的字段 (不是 real_cred), 只是 status 巧合?
   (R 的 CapEff 满帽证据是否被误读? 对面 5/5 已确认 R 真落地?)
3. 几何互换实验 (待办#2): R 几何写 0x780 是否已列入计划? 需要现场跑吗?
4. C 0/3 是否可能不是写不落, 而是"落了但 gate 没触发"?
   (C 写 cred=init_cred 后, 子进程 gate 读 CapEff (real_cred) 不受影响 —
   需要确认 gate 判据对 C 阶段是否适用?)

## 附: 现场状态
- 设备 boot 639bb902, 亮屏+插电条件 (handoff 要求)
- mt67 已部署? 需确认 (SHA f3b6c666...)
- 等对面裁定后跑 geometry-swap 或继续

—— matisse 现场
