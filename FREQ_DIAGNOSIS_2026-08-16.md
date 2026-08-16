# "不热但 350M" 裁定 — 归因转向功耗管理；保频栈 + freqgate v2（外部评审，2026-08-16）

> 回复 `FREQGATE_FAIL_2026-08-16.md` 四问 + 追加两问。
> **一句话：热温控降级为次要嫌疑，主嫌是省电/功耗管理（时间线完美吻合）；
> 先花 2 分钟验证电池假说；保频用 framework 的 `cmd power/thermalservice`
> （shell 在 A12 持有 DEVICE_POWER，合法且可逆）；freqgate 改为"始终记录 +
> 每轮重发保频"，不再跳轮；350M 是否必 miss —— 无证据，别再推理，用
> logenv 相关性数据裁。**

---

## 一、归因更新：时间线指向电池/省电，不是热

```
上午 (满电冷启): 09:52 ✅ P0-A → 11:29 ✅ mt47 → 13:15 ✅ → 13:5x ✅
下午 (3 次崩溃 + 6 次重启 + 屏常亮调试之后): 14:5x 起 6 连灭,
   16:02 开局 1.8G → 3s 后 550M → 350M, 手机不烫
```

"不烫但 350M" + 下午才出现 = **功耗预算类 clamp** 的教科书特征，候选排序：

1. **MIUI 省电模式 / 低电量**（`dumpsys battery` 的 level + low_power 标志；
   电量 <20% 或省电模式开启时 MIUI/MTK powerhal 压 max_freq）—— 上午满电
   下午亏电，与成败切换时间完全同构，**2 分钟可验**；
2. **MTK powerhal perf-lock / joyose scene 引擎**（按前台场景给频，shell
   终端不被识别为性能场景）；
3. thermald native（手机不烫 + 我们只看了 thermal_zone0，枚举全部 zone 后
   若全凉则排除）。

**先做（下次跑前，共 2 分钟）**：
```
dumpsys battery | grep -iE 'level|status|low'   # 电量 + 省电标志 ← 第一优先
settings get global low_power                    # 0=关 1=省电模式
dumpsys power | grep -iE 'mode|adaptive|boost'   # 框架侧模式
dumpsys thermalservice | head -30                # 热状态 (status>0 才是热)
cat /sys/class/thermal/thermal_zone*/temp        # 枚举全部 zone (别只看 zone0)
```
电量低 → **充到 40% 以上再跑**。这可能就是整个下午的故事。

## 二、新的头号机制候选：core hotplug（比频率更致命）

省电模式/功耗管理在压频之外还会 **hotplug 小核**（cpu1-3 offline）。我们的
race 把 consumer 钉死在 `CONSUMER_CORE=1`（编译期 `#define`，common.h:55，
无 env 覆盖）—— **cpu1 一旦 offline，绑核失效/迁移，race 直接死，与频率无关**。
这能同时解释"prepare 正常（起跑时核在线）+ wrote=0（跑动中被拔核）"。

下次跑前补一条：`cat /sys/devices/system/cpu/cpu{1,2,3}/online`（cpu0 恒在线
无此文件）。logenv v2 已把它加进每轮记录。若命中/未命中与 cpu1 online 相关
而与频率无关 → 机制就是 hotplug，对策是充电+关闭省电（充电态一般不拔核）。

## 三、shell 合法保频栈（A12，全部重启即逆，按序）

回答 FREQGATE_FAIL 追加问 2（"shell 有没有合法路径保高频"）——**有，走
framework 服务，不走 sysfs**：

```
cmd power set-fixed-performance-mode-enabled true   # ★主杠杆: 冻结 DVFS 到性能
cmd thermalservice override-status 0                # 中和框架热状态 (非热也无害)
cmd power set-adaptive-power-saver-enabled false    # 关自适应省电
settings put global low_power 0                     # 若 §一 查到省电标志开
```

依据：shell uid 在 A12 持有 `DEVICE_POWER`（signature|privileged 授予 shell），
`cmd power/thermalservice` 走的就是它——这与直接写 root:root 的
`scaling_setspeed`（注定 EACCES）是两条路。**外加物理杠杆：插充电器**
（若 clamp 是功耗预算类，充电直接解除预算约束）。

**验证闭环**（保频是否生效，20 秒）：
```
for i in $(seq 20); do
  cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq \
      /sys/devices/system/cpu/cpu1/cpufreq/scaling_cur_freq; sleep 0.1
done
```
若 fixed-perf + 充电 + 电量足之后 cur 仍长期 350M → clamp 在 MTK native
hal/kernel 侧（shell 到顶了）→ 接受低频，靠 §四的相关性数据说话。

顺带修正：16:02:10 那条 `freq0=350M freq1=1.25G` —— 两个 cat 非原子，
可能是切换瞬间跨读；但若 20 次快采样仍频繁出现同刻不等，则此机型是
**per-core DVFS**，我此前"同簇同频"的修正要再翻回来（异步降频对窗口的
威胁成立）。上面 20 连测顺带裁定这一点。

## 四、350M 是否必然 miss？—— 无证据，停止推理，用数据裁

回答 FREQGATE_FAIL 问 2。两个方向都拿不出证据：

1. **"抖动杀窗口"被历史反证**：Android 的 DVFS（schedutil/interactive）
   **平时就在秒级跳频**，上午成功的那些轮同样在跳频中跑出来的。若 3 秒级
   抖动足以杀死窗口，历史上应该零命中 —— 与 4 次成功矛盾。
2. **"全速就能中"也被反证**：15:4x 那轮 STAGE-R 是 force-stop joyose 后
   1.4-1.8G 跑的，照样 4 轮全灭（概率 13%~41%，不异常）。

结论：**频率作为命中率的决定变量，两个方向都是未证明状态**。logenv 已在
每轮记录，攒 ≥8 轮 hit/miss × freq 做相关性，一翻两瞪眼。在那之前不改
`SLIDE_CONSUME_USEC`、不重编、不绑大核（CORE 是 #define，改动=重编+重校准，
而 A510@1.8G 上午刚证明能命中）。

## 五、freqgate v2：从"闸门"改为"保频+全量记录"（三处失败逐一闭环）

现场三处失败（force-stop 无效 / max 读不到 / 无日志输出）的处置：

| 现场 observed | 根因 | v2 处置 |
|--------------|------|---------|
| force-stop joyose 无效且复活 | system 服务级自愈 | 不再碰 joyose，改 §三 cmd power 栈（幂等，每轮重发） |
| scaling_max_freq 空 | `system:system` 组文件，shell 无读权（预期行为） | 弃用 max，改 cur 配对采样 |
| freqgate 零输出 | 静默成功路径无日志 + 疑似设备上是旧脚本 | v2 **任何路径必留一行日志**；请确认设备上脚本已更新 |

结构性修正：**轮前闸门本来就护不住轮中降频**（16:02 数据显示 clamp 在
round1 起跑 3 秒后就落下，闸门在起跑前查是瞎的）。所以 v2 删掉跳轮逻辑
（`freqgate || continue` → `freqgate`），每轮：重发保频命令 + 采样记录 +
电池/在线核快照。跳轮留给 STAGE-C 阶段（写已落地一半时更怕环境突变）——
不，简单起见 v2 统一不跳，纯记录。

## 六、其余问答收尾

- **散热垫/空调**：非热归因下无关。仅当 §一 枚举 thermal zone 发现某传感器
  真热（如 modem/充电 IC，手摸不到）才回头考虑。
- **pstore**：ASK 回执收到 —— 栈未留存，维持现裁定，下次崩溃第一动作拉
  `cat /sys/fs/pstore/console-ramoops-0`（你们已确认 cat 可读、ls 的 EACCES
  是假象）。
- **执行序**不变：换新 boot → 稳 5-10min → §一诊断 2 分钟 → §三保频 →
  `SKIP_R0=1 sh test_mt49_root.sh` → STAGE-R(×4) → STAGE-C(×4) →
  子进程 setenforce + finit_module。

—— 外部评审（这次把"该问 dumpsys 还是 sysfs"都分好了）
