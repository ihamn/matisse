# 回执裁定 + 明晨配方 v3（评审，2026-08-16 深夜·第三班）

> 逐条核对 FIELD_TASKS_REPLY。**任务3 的答案比你以为的重要得多——
> 你把 jackpot 当普通清单交上来了**（见 §三）。rc=255 的机制解释我不收，
> 理由在 §一。明晨 runbook 升级为 v3，见 §四。

---

## 一、任务1（rc=255 出处）：结论不收，证据本身有用

你定位的行是真的（main.c:738-740 我核过），但因果链两头都错：

1. **`_exit(2)` 的退出码是 2，不是 255**。退出状态取 `& 0xFF`，
   `_exit(2)` → rc=2；255 对应 `_exit(-1)`。全源码 grep **不存在任何
   `exit(-1)`/`_exit(-1)`**（现存出口只有 1 / 2 / 42 / 0 / 127）。
2. **fork 子进程的退出码不会变成父进程的 rc**。harness 的 `$?` 来自
   `timeout → env → sleep`（即 preload 宿主），main.c:740 那个
   `_exit(2)` 在 8 分钟子进程里，它只影响自己。

**你的证据真正证明的是**：hunt_1.out 尾部出现 8 分钟窗口结束行 =
子进程继承了 fd 活着写完整个窗口（poll=2350）→ 机制稳定不崩。
这个和 boot_id 未变互证，**这个结论我收**。

rc=255 真实出处仍未定位，且**不在现仓库源码里**——大概率在你们
当晚 ad hoc 的猎赢脚本本身（`rc=$?` 前面还有没有别的命令/管道）。
**请把那份猎赢脚本原样推仓库**（一个文件的事）。账本层面维持我的
裁定：rc 只记录不判活，判活以 boot_id 为准。

## 二、任务2（13:15 四轮 rc=124）：收

与我的审计一致，0/4 全 timeout 击杀。顺带一个待你脚本确认的旁证：
13:15 的父进程 120s 时还活着（被 timeout 杀），晚上的父进程则不是
124——两组行为不同，脚本到位即可闭环。

## 三、任务3（旧 .so 清单）：★全场最重要的一条★

你说"mt25 最相关 (ENF 成功时代)"——不止相关：

**mt26 胜局脚本（test_mt26_selinux.sh:4）写明 `SRC=preload_mt25.so`。
唯一一次 ENF 胜利就是 preload_mt25.so 跑出来的，这个文件还在。**

而我在比对胜局脚本与之后全部 9 轮 ENF（13:15 ×4 + 晚上 ×4 + 探针 ×1）
的 env 时，发现**三项同时偏离**，此前没有任何文档标记过：

| 参数 | mt26 胜局 | 之后全部 9 轮 | 物理含义 |
|------|----------|--------------|---------|
| 二进制 | **preload_mt25.so** | mt47→mt52 各版 | 代码轴 |
| `PSELECT_SKIP_WARMUP` | **=1** | 全部未设 | slide.c:584 mt16：跳过重喷，**slab 压力减半** —— 直接改变喷页格局 |
| 窗口 | `timeout 220` + `sleep 180` | `timeout 120` + `sleep 70` | 每轮驻留时长 |

（mt47/49 脚本我逐行核过，ENF 块确实无 SKIP_WARMUP。）

**这改写明晨实验设计**：之前"0/8 最佳解释 = 环境+概率"的裁定要再
降一档——现在有具体、可逐项复原的配方差异嫌疑。你不是"没中过"，
是**从没用胜局配方跑过**。

另一个请求：**把 preload_mt25.so 推进仓库**（170KB，git 完全装得下）。
我在沙箱里对 mt25 和当前版做触发路径反汇编 diff，把"代码轴"从
二选一的 A/B 升级成精确定位到函数。这个我做，不占你设备时间。

## 四、任务4（mt26 原始行丢失）：收，闭环

诚实报告是好习惯。win 签名维持代码派生版（某发 `ret=0` = win，
全 `errno=110` = miss），此账关闭。

## 五、明晨 runbook v3（覆盖 INDEP_AUDIT §三的 3+3 拆分）

前置照旧：隔夜充电 ≥80%、冷启动、settle 5-10min、logenv 打头
（频率/温度/电量/loadavg）、每轮起止时间戳。**每轮跑前 `am kill-all`**
（胜局脚本原词，一并复原）。

**Block A — 胜局配方复原（2 轮）**：
```sh
am kill-all
timeout 220 env \
  PSELECT_SLIDE_TRIGGER=1 \
  PSELECT_RETRY=1 \
  PSELECT_TREE_PC=ffffff8002a41b90 \
  PSELECT_TREE_LEFT=0 \
  PSELECT_SKIP_WARMUP=1 \
  LD_PRELOAD=/sdcard/Documents/matisse_backup_essentials/preload_mt25.so \
  /system/bin/sleep 180 > /data/local/tmp/huntA_$N.out 2>&1
echo "A round=$N rc=$? enforce=$(getenforce)"
```
二进制 + env + 窗口三项全部复原，唯一变量 = 今天 vs 08-15 晨。

**Block B — 代码轴隔离（2 轮）**：同 Block A 命令，仅把 LD_PRELOAD
换成当前版（从 HEAD 重编，mt54 钩子不设 env 即逐字节旧行为）。
A/B 对比 = 同 env 同窗口下的纯二进制变量。

**Block C — v2 网格（≤2 轮）**：ENF+机制（GEOM_KEEP 那套），
仅在 A/B 出结果后跑。

**判读表**：
- A 中 → 胜局配方复活（env 参数轴定罪）；B 同时不中 → 代码轴也定罪
  （等我 mt25↔当前 diff 报告定罪到函数）
- A 全 miss（频率日志核实过满速）→ "晨窗"故事失去最后支柱，
  p̂ 重估，等我的反汇编 diff 再定下一步，**不要现场加轮**
- 任何 panic → pstore 原文第一
- win 后：父 shell 观察 60s（getenforce / 子进程），触发进程让它退

**判活永远看 boot_id，rc 只记不判。**

## 六、设备侧待办（睡前 5 分钟）

1. push 猎赢脚本原文（rc=255 闭环）
2. push preload_mt25.so（我做离线 diff）
3. 从 HEAD 重编当前 .so（Block B 用；mt54 默认行为与 mt52 逐字节一致，
   不设新 env 不会有新变量）

—— 评审（deepseek 名义）· 胜局配方三项偏离是我今晚唯一的净新增，
其余为对你回执的核对与裁定
