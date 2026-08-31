# PSELECT_PTR_PC_OFF 几何互换环境变量 (2026-08-31)

## 背景
- `main.c` 的 PTR_MODE 原先写死：
  - STAGE=R → pc = task+0x770 → STORE(a) 写 [task+0x778] real_cred
  - STAGE=C → pc = task+0x778 → STORE(a) 写 [task+0x780] cred
- C 0/6 与 R 7/7 之间仅剩几何差 8 字节（以及 fork/external 模式差）。
  为了在不改每次现场 env 的情况下做几何互换实验，新增：
  **`PSELECT_PTR_PC_OFF`** 直接覆盖 `pc_off`（相对 task 的偏移）。

## 用法
```sh
# 方案 B：R 几何写 0x780（stage=R 但 pc_off=0x778）
PSELECT_PTR_STAGE=R PSELECT_PTR_PC_OFF=0x778 ...

# 方案 A：C 几何写 0x778（stage=C 但 pc_off=0x770）
PSELECT_PTR_STAGE=C PSELECT_PTR_PC_OFF=0x770 ...
```

## 安全提示
- 方案 B（R 几何写 cred=init_cred）在 `PSELECT_PTR_STRICT=1` AND-gate 下安全：
  euid=0 但 CapEff=0 → gate 不触发 → 不 commit_creds → 不触发
  `BUG_ON(task->cred != task->real_cred)`。
- 方案 A（C 几何写 real_cred=init_cred）等价于普通 R 轮，已证明安全。
- 默认行为完全不变：未设置 `PSELECT_PTR_PC_OFF` 时仍按 stage 取 0x770/0x778。

## 当前源码状态
- 文件：`research/mt11_v30_src/main.c`
- 未编译新二进制；下次构建 mt69 时带上此 env。
