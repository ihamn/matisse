# 独立分析（对面无余额后）：C 阶段 gate 判据确认 + 下一步 (2026-08-30)

## 问题 #4 结论：C 0/3 = 写不落，非 gate 问题（代码级）
```
main.c:624-635 (PSELECT_PTR_STRICT AND-gate):
  gate_hit = (capeff >= 0x1ffffffffff) && (euid == 0);
  - CapEff 读 real_cred (status) ← R 写后满帽
  - euid 读 cred (getresuid)     ← C 写后为 0
```
C 写 cred=init_cred → euid=0 → gate 必触发 → root_alive.txt。
C 0/3 实测 root_seen=0 → **C 写确实没落** (非 gate 未触发)。

## 剩余真问题
pc=0x770 (R) 写 [task+0x778] 稳定落地 vs pc=0x778 (C) 写 [task+0x780] 0/3。
唯一差异 = pc 偏移 8 字节 + 目标字段 (real_cred vs cred)。

## 待办 #2: 几何互换实验 (隔离 pc 偏移 vs 写目标)
对面 HANDOFF 提的: "R 几何写 0x780" — 但需要想清楚怎么跑:
- 方案 A: stage=C 但 pc 偏移用 0x770 (写 0x778=real_cred) → 对照 C 是否
  能落 (隔离 pc 值 vs 目标字段)
- 方案 B: stage=R 但 pc 偏移用 0x778 (写 0x780=cred) → 对照 R 几何下
  写 cred 是否落 (对面原话"R 几何写 0x780")
- 但 B 有风险: 写 cred=init_cred 后 euid=0 → 若 gate 触发 → setresuid →
  commit_creds → real_cred(未换) != cred(已换) → BUG_ON → panic!
  (半程态不安全!) → 需要 PSELECT_PTR_STRICT 的 AND-gate 保护 (euid=0
  但 CapEff=0 → gate 不触发 → 安全)

## 建议 (等设备恢复)
1. 方案 B (R 几何写 0x780) 安全前提: PTR_STRICT AND-gate 下 euid=0 但
   CapEff=0 → 不触发 → 无 panic 风险 (半程态结构性安全)
2. 若 B 落地 → 证明 pc=0x770 几何能写, 问题在目标字段 (cred vs real_cred
   的 rb 树语义差异)
3. 若 B 也不落 → 问题在 pc 偏移本身 (0x778 在 rb_erase 里有特殊语义)
4. 跑法: 现场 stage=C env + 修改 pc_off? 需要小改 main.c (无对面时自己编)

## 设备状态
- boot 639bb902, Shizuku 断 (需重开)
- mt67 二进制待确认部署
- 等 Shizuku + 决定实验跑法

—— matisse 现场 (独立模式)
