# CHECKPOINT R5 — prepare_kernel_page 内部分阶段诊断

## 问题
R4 在 **第一次** `prepare_kernel_page()` 内部就重启了，连 retry 循环都没进去。
sleep 修复（在 retry 之间）完全无效 — 因为根本到不了 retry。

## R5 改动

### prepare_kernel_page (util.c) 内部植入 11 个 phase 日志点:

```
phase0  cleanup        — 清理旧状态
phase1  cloneA         — 克隆 prepare_ctx + spray_ctx (~350 个进程)
phase1a done           — 第一批克隆完成
phase1  done           — 第二批克隆完成 (中间有 sleep(1))
phase2  ks_setup       — kernelsnitch 初始化
phase3  cloneB         — 克隆 pre_ctx + post_ctx (~49 个进程)
phase3a leak_child     — 克隆泄漏探测子进程
phase3b post           — 克隆 post_ctx
phase3  done           — 等待 leak_child 结束 (中间有 sleep(1))
phase4  ks_check       — 检查 kernelsnitch 碰撞
phase5  ks_bruteforce  — 暴力破解泄漏地址
phase6  leaked=        — 获得 mm_struct 地址
phase7  sockpair       — 创建 reclaim socket + shaping socket
phase8  free holes     — 释放 spray/pre/post 空洞
phase9  reclaim sends  — SKB 回收发送
phase10 cleanup return — 清理并返回 base 地址
```

### 额外保护:
- **每 64 个 clone 之间 usleep(10ms)** — 减缓进程创建速率
- **大阶段之间 sleep(1s)** — 等内核 GC
- **每个 phase 日志后 fflush(stdout)** — 确保崩前输出不丢

## 运行步骤 (重要!)

1. **手机刚重启完** → 等至少 5 分钟让内核服务全部启动稳定
2. Shizuku 启动
3. rish 部署:
   ```
   cp /sdcard/Documents/matisse_backup_essentials/preload_mtk_R5.so /data/local/tmp/preload.so
   ```
4. rish 运行:
   ```
   LD_PRELOAD=/data/local/tmp/preload.so /system/bin/sleep 10 2>&1 | tee /sdcard/Documents/matisse_backup_essentials/logs/R5_test1.txt
   ```

## 预期结果

如果走到 phase6+ → 前面的 clone+spray 不是问题，崩溃在后续阶段
如果止步 phase1/1a → clone 自身导致 slab 耗尽，需要降 clone 数量
如果止步 phase2 → kernelsnitch 初始化问题
如果走到 phase10 → 全部通过，问题在其他地方

## SHA256
R5: cdac2d0d63dc91bb91a94c7de99a1b0058cc5d2e032a5ced9233022201f7e623
R4: 40adc21d011cdd2865261b9ab632d3c58470f0234afbb4b70512595d2c1b03ef
R3: 017fb8a67a6aecd7a7c6ad1f94c73ca9ca97d6cfa332a2168614a614fdac2b9c
