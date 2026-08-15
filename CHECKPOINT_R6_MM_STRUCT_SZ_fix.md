# CHECKPOINT R6 — MM_STRUCT_SZ 修正 + v30 cooldown 移植 + KASLR 硬编码

## 致命 Bug: MM_STRUCT_SZ 0x500 → 0x3C0

**53 次 R 系列测试全部失败。** `grep 'phase6\|leaked=' logs/*.txt` → 全部 0。

| 参数 | v30 (成功) | R1-R5 (全部失败) |
|------|-----------|-----------------|
| MM_STRUCT_SZ | **0x3C0** (960B) | **0x500** (1280B, 错误!) |
| sizeof(mm_struct) MTK 5.10 | 0x3C0 | — |
| bruteforce 扫描步长 | 0x3C0 (命中) | 0x500 (错过所有) |

## R6 改动总览

### 1. common.h: MM_STRUCT_SZ 0x500 → 0x3C0 ★ 最关键
使 bruteforce 扫描步长匹配内核实际 sizeof(mm_struct)。

### 2. main.c: KASLR 硬编码 + warmup (替代 GhostLock slide leak)
- 设备 KASLR=0 → `kaslr_base = KIMAGE_TEXT_BASE` 直接硬编码
- 一次 SLIDE page prep warmup → 3s cooldown → direct stage
- 避免 GhostLock slide leak 的双重 page prep，大幅减少 slab 压力

### 3. util.c: 移植 v30 全部 12 个 MTK cooldown ★ 防重启
基于 v30 经验，每个 cooldown 都有明确目的:

| # | 位置 | 时间 | v30 注释 |
|---|------|------|---------|
| 1 | cleanup_page_prepare_state | 1s | give kernel time to reclaim freed resources |
| 2 | phase0 开始 | 隐式 | let kernel reclaim before heavy clone/kill cycle |
| 3 | phase1 结束 (350 clones) | 3s | heavy cooldown after clone — avoid system ANR/reboot |
| 4 | phase2 ks_setup 后 (64GB mmap) | 1s | cooldown after ks_setup mmap before more clones |
| 5 | phase3 结束 (pre+post clone) | 1s | cooldown after pre+post clone |
| 6 | phase3b pre-ks cooldown | 2s | let kernel reclaim dead children before heavy ops |
| 7 | phase4a pre-bruteforce | 500ms | brief cooldown before collision check heavy futex ops |
| — | (implicit) | — | cooldown before bruteforce (scans identity map) |
| 8 | phase7 前 SKB reclaim | 1s | cool down before SKB reclaim sends |
| 9 | 每 64 clone 之间 | 10ms | per-batch micro-cooldown |
| 10 | retry 之间 | 2s | avoid kernel panic from rapid clone/kill cycling |
| 11 | main.c warmup cooldown | 3s | give kernel time to reclaim dead processes |

**单次 attempt 总 cooldown: ~12s** (v30: ~14s, R5: ~4s)

### 4. util.c: kernelsnitch verbose=1
输出 bruteforce 进度，可诊断扫描范围是否正确。

### 5. common.h: SLIDE_KERNEL_PAGE_SETUP_ATTEMPTS 5 → 3
减少重试，每次重试都会 clone 350 进程 → 降低 slab 耗尽概率。

### 6. slide.c: SLIDE_MAX_ATTEMPTS 20 → 3
外层重试减少。

## R6 vs R5 vs v30 对比

| | R5 | R6 | v30 |
|---|-----|-----|-----|
| MM_STRUCT_SZ | 0x500 (错) | 0x3C0 (对) | 0x3C0 (对) |
| KASLR 获取 | GhostLock leak (永远失败) | 硬编码 | 硬编码 |
| cooldown/attempt | ~4s | ~12s | ~14s |
| sleep 点数 | 6 | 11 | 12 |
| retry 次数 | 5 | 3 | 原始值 |
| slab 压力 | 极高 | 中等 | 中等 |
| bruteforce 日志 | 无 | verbose | 无 |
| 预期重启概率 | ~100% | 大幅降低 | ~10% |

## R6 运行流程

```
1. 硬编码 KASLR (kaslr_base = KIMAGE_TEXT_BASE)
2. MTK warmup: prepare_good_kernel_page(SLIDE), max 3 retries
   - 每次 attempt: ~12s cooldown, 350 clones
3. cleanup + sleep(3) MTK cooldown
4. run_direct_root_stage()
   - fork 子进程
   - 子进程内 prepare_good_kernel_page(SLIDE), max 3 retries
   - GhostLock pselect → per_cpu_offset → __entry_task → cred 覆写
   - 输出 direct-root-summary root=1
```

## 运行步骤 (⚠️ 认真执行!)

1. **手机刚重启完 → 等 5 分钟让内核稳定**
2. Shizuku 启动
3. 确保不自动息屏
4. rish 部署:
   ```
   cp /sdcard/Documents/matisse_backup_essentials/preload_mtk_R6.so /data/local/tmp/preload.so
   ```
5. 只跑一次:
   ```
   LD_PRELOAD=/data/local/tmp/preload.so /system/bin/sleep 10 2>&1 | tee /sdcard/Documents/matisse_backup_essentials/logs/R6_test1.txt
   ```

## 预期结果分级

**🏆 完美**: `slide-kaslr-mtk-hardcoded` → warmup `ok=1` → `direct-root-summary root=1`
**✅ 可接受**: warmup `ok=0` 但 direct stage bruteforce 成功 → `root=1`
**⚠️ 需分析**: bruteforce 仍失败但 verbose 日志有数据 → 看扫描范围和碰撞
**❌ 最差**: 重启 → 说明 slab 问题仍在，需进一步减少 clone 数量

## SHA256
```
R6 final: e2289c64fa0dd4a427f4312db531813c3028627db8f154594f22ad5aeaa56c5b
R5:       cdac2d0d63dc91bb91a94c7de99a1b0058cc5d2e032a5ced9233022201f7e623
R4:       40adc21d011cdd2865261b9ab632d3c58470f0234afbb4b70512595d2c1b03ef
R3/R2/R1: 017fb8a67a6aecd7a7c6ad1f94c73ca9ca97d6cfa332a2168614a614fdac2b9c
```
