# CHECKPOINT R7 — 回归v系列快速风格，砍掉所有内部cooldown

> 编译时间: 2026-07-16
> SHA256: ce945969a8697ed47a1516143e557cbd94d0402307c903553772ac9310448efa
> 文件: preload_mtk_R7.so

---

## ☠️ R6 根因分析

R6虽修复了MM_STRUCT_SZ=0x3C0，但仍在prepare_kernel_page内部加了sleep(3)+sleep(1)+sleep(1)+sleep(2)+usleep(500000)+sleep(1) = **约9秒内部cooldown**。每次调用耗时~12秒，期间fork出的僵尸进程在sleep期间堆积，内核无法有效回收。

**v系列铁证**: v20/v22/v24/v25各版本均跑11次prepare_kernel_page（每次543 clone），零重启。v系列prepare_kernel_page内部**完全无cooldown**，全部快速完成（~2-3秒/次）。

## R7 改动 — 回归v系列验证过的参数

### 1. 砍掉warmup (main.c)
- KASLR=0硬编码在v20-v30中验证50+次，无需warmup「priming slab」
- warmup本身就是一次 prepare_kernel_page（543 clone + 64GB bruteforce扫描），纯浪费
- 替代: 直接5s冷却后进入direct stage

### 2. 砍掉prepare_kernel_page全部内部cooldown (util.c)
| 删掉的cooldown | R6时间 | 理由 |
|---|---|---|
| phase1后 sleep(3) | 3s | v系列不需要 |
| phase2后 sleep(1) | 1s | v系列不需要 |
| phase3后 sleep(1) | 1s | v系列不需要 |
| phase3b后 sleep(2) | 2s | v系列不需要 |
| phase4后 usleep(500ms) | 0.5s | v系列不需要 |
| phase7前 sleep(1) | 1s | v系列不需要 |
| **总计节省** | **~8.5s/次** | — |

**保留的**:
- per-64-clone usleep(10ms) — 批间微冷却，不积压僵尸
- cleanup usleep(100ms) — 从1s缩短
- retry usleep(500ms/100ms) — 仅在retry时触发

### 3. 所有重试=1
| 参数 | R6 | R7 |
|---|---|---|
| SLIDE_KERNEL_PAGE_SETUP_ATTEMPTS | 3 | **1** |
| DIRECT_WRITE_ATTEMPTS | 3 | **1** |
| pipe.c followup attempts | 3 | **1** |

### 4. 5秒冷却 (main.c, 匹配v系列)
v20-v25全部使用`MTK cooldown ... sleeping 5s`（v25_test1/test2均有日志记录），R7同样采用5s。

## R7 运行流程（极简）

```
1. 硬编码 KASLR=0
2. sleep(5) — v系列验证过的冷却
3. run_direct_root_stage()
   ├─ direct_read per_cpu_offset: fork → prepare_good_kernel_page(SLIDE, 1次) → GhostLock
   ├─ direct_read entry_task:       fork → prepare_good_kernel_page(SLIDE, 1次) → GhostLock
   ├─ direct_write real_cred:       fork → prepare_good_kernel_page(SLIDE, 1次) → GhostLock
   └─ direct_write cred+selinux:    fork → prepare_good_kernel_page(SLIDE, 1次) → GhostLock
                                    └─ followup: fork → 1次 → GhostLock
```

**最坏情况 prepare_kernel_page 调用次数**: 5次 (vs R6的 ~16次)

## 运行步骤

```
1. 手机刚重启完 → 等至少5分钟
2. Shizuku启动 → rish部署:
   cp /sdcard/Documents/matisse_backup_essentials/preload_mtk_R7.so /data/local/tmp/preload.so
3. 运行:
   LD_PRELOAD=/data/local/tmp/preload.so /system/bin/sleep 10 2>&1 | tee /sdcard/Documents/matisse_backup_essentials/logs/R7_test1.txt
```

## SHA256确认
```
R7: ce945969a8697ed47a1516143e557cbd94d0402307c903553772ac9310448efa
R6: e2289c64fa0dd4a427f4312db531813c3028627db8f154594f22ad5aeaa56c5b
R5: cdac2d0d63dc91bb91a94c7de99a1b0058cc5d2e032a5ced9233022201f7e623
R7 ≠ R6 ≠ R5 ✅
```

## 预期重启概率

基于v系列经验(v20-v25六次成功零重启)，R7重启概率应大幅低于R6。
如果bruteforce仍失败(MM_STRUCT_SZ可能仍不对或其他原因)，单次失败不会重试，
不会累积内核压力。最多5次快速prepare_kernel_page调用后正常退出。
