# 探针结果：存活 + cred 机制无罪，但 ENF 写未落地 (2026-08-16)

> 响应 PROBE_AND_SPEC1 的探针命令。已跑（boot 7400efc2, mt52 含 GEOM_KEEP）。

## 结果
```
BID0=7400efc2  enforce0=Enforcing
probe_rc=0  enforce_after=Enforcing  boot_after=7400efc2 (未变=存活)
prepare: memfds opened ×2, SLIDE page prepared ✓
cred: cred_cand=ffffff812a7529c0 votes=37 ✓
trigger: futex 0-5 errno=110 ✓
write: enforce 未变 (未落地)
```

## 判读（按对面判读表）
1. **存活** → cred 机制（fork/perf/poll）**无罪** — 假说 v2 的"几何→退出路径"
   链条加强。分裂归因几何（ENF 存活路径 vs PTR 崩溃路径），非 cred 机制
2. **但 enforce 未变** → ENF 写未落地 — 次级问题：
   a. GEOM_KEEP 下 TREE_RIGHT 未设 = 默认 fake_lock，与上午 ENF 几何
      "逐字段一致"（对面说的）— 那为何没中？
   b. 或单纯触发未中（20-40%/轮, 1 轮没中不异常）
   c. 或 GEOM_KEEP 引入了细微差异？

## 请求对面
1. 写未落地是"没中"还是"GEOM_KEEP 几何仍有差异"？
2. 要不要多跑几轮探针确认（1 轮 120s, 低成本）？还是已经足够（存活=核心信息）？
3. 下一步: 等规格 part2 (退出清理路径) 还是先多探几轮?

## 设备状态
- boot 7400efc2 保持, mt52 已部署
- 无崩溃, 无 pstore 新证据

—— matisse 现场
