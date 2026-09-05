# CHECKPOINT — mt79/E5v3r2 + 09-06 凌晨现场轮复盘 (R✓ / E5v3安全拦截 / C中断+软重启)

## 现场时间线 (2026-09-06 01:09-01:20, boot=ab549482 全程未变 → 内核始终存活)
1. 01:09 R 轮(CPU6, mt78 build): perf task=0xffffff80426e4a00 (198/256票),
   6 发风暴全正常 → **CapEff=000001ffffffffff 落地 ✅** (连续第 8 次 R 成功)
2. 01:11 E5v3: fake_lock=0xffffff81062c04d0 (页基址+0x4d0, 尾字节 d0) →
   mt78 运行时校验器 ABORT ✅ 零事故 (设计目标达成)
3. 01:14-01:17 C 轮 (无 E5, 直打 R-child, stage C): 触发链完整
   (EDEADLK 35 → FWRQ 110 → UNLOCK_PI 0 → pselect 窗口上膛 6 发)
4. ~01:18 **软重启** (framework 级; boot_id/uptime 连续, 非内核 panic)
   → C 进程被连带杀死, 窗口内是否命中【无法判定】; logcat 滚动/dropbox
   拒读, 用户态死因取证到头 (system_server 死亡, 与历史自发软重启同型;
   load 16.7 + 每轮克隆 500+ 进程的内存压力是重要诱因)

## 根因修正: mt79 (E5v3r2)
- fake_lock = payload_base+0x1350, payload_base = page_base-0xe80 → 非页对齐!
- 修正: E5 child 用 ★page_base★ (真页对齐): SPRAY=page_base (byte0=00 →
  enforcing=0), SPRAY1=page_base+1 (byte0=01 → enforcing=1)
- byte2=0x2c ≠0 (initialized 保留); 校验器 (byte0∈{0,1}, byte2≠0) 不变
- STORE(b) 污染页首 0xe80 布局零区 — put64 布局从不写该区, 牺牲安全
- preload.so SHA256: 75728bb8b2e31c4cb91165859016d0866635b3ba8a888cf00e96ad5333c9e85e
  已部署 /data/local/tmp/preload.so + 工作区 preload_mt79.so

## 现场纪律更新 (软重启教训)
- ★load gate 不再放宽: >15 一律不跑★ (01:17 轮 load 16.7 是本项目首次
  顶着超载开火, 结果就是软重启 — 相关性已记录)
- 每轮 storm 克隆 500+ 进程; 连续轮之间至少隔 3-5 分钟让内存回收
- 软重启 ≠ 内核崩溃 (boot_id 判别): uptime 连续 = framework 重启, pstore
  不会有新 panic, 别浪费轮次找

## 下一步
1. E5v3r2 (SPRAY 默认) 现场一轮 — 判定 v1 黑屏根因 (H-A vs initialized=0)
2. 无 E5 的 C 轮重试 (mt73 sethostname 信标 + R 先行) — 本次 C 因软重启
   中断, 内核全程无恙说明双 erase 也不 panic, 可在低负载下重试
3. C 铁证 (hostname=glroot / Uid:0) 拿到即 root 到手; E5 只剩 KSU 加载用途
