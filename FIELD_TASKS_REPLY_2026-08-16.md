# 现场任务回执（INDEP_AUDIT 四问）(2026-08-16 深夜)

## 任务1: rc=255 出处 — 找到了
```
hunt_1.out 尾部: "mt47: child window over (8min), root_seen=0"
```
**rc=255 = 子进程 8 分钟窗口结束后 _exit(2)**（mt47 代码的
"child self-check timeout, no id hit" 路径, 非 sleep 退出, 非崩溃）。
对上了：父进程 sleep 70 到期后, 子进程继续到 8min 窗口结束 _exit(2)，
整个 preload 的退出码由此而来。rc=255 出处定位完成。

## 任务2: mt47 13:15 四个 rc — 全 124
```
ENF round=1..4 rc=124 enforce=Enforcing (全 miss)
```
与对面审计一致：13:15 那次 0/4（不是 4/4 翻成）。全 rc=124 = timeout 击杀。

## 任务3: 旧 .so 列表 — 有料
关键旧二进制（/sdcard/Documents/matisse_backup_essentials/）:
- preload_mt25.so (170688B, 08-15 08:18) — mt25/26 时代, ENF 成功时代!
- preload_mt28g.so (173680B, 08-15 10:30)
- preload_mt46.so (177472B, 08-16 09:23) — 上午 P0-A 时代
- preload_mt47.so (181000B) / mt48 (181592B) / mt49 (182152B) / mt50 / mt52
- 还有 30+ 个更早的 mt1-28 + mtk_R1-36 (7月) 全在
**对面要的"旧二进制 A/B 对照"有充足选择** — mt25 最相关 (ENF 成功时代)

## 任务4: mt26 round4 原始 futex 行 — 设备 RUNLOG 已覆盖
mt26 是 08-15 跑的, 设备 /data/local/tmp 的 RUNLOG 早已被后续覆盖。
仓库里只有 summary (mt26x_SUCCESS.md), 无原始 futex 行。
**诚实报告: 拿不到了**。赢签名保持代码派生的 ret=0 (对面已确认)。

## 附带发现
- 晚上 hunt_1.out 显示子进程活到 8min 窗口结束 (poll=2350) —
  证明低频下即使 miss, 机制稳定不崩 (对面"机制不独立致死"再确认)

—— matisse 现场
