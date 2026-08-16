# 黑屏冻结机制终审：因果链闭合（评审，2026-08-16 第七班）

> 四份证据（A1_2.out / arc_log / run_arc.sh / pstore 尾部）全部到手并
> 逐字节读完。**机制假设 B 的精确形态胜出：不是负载饿死，是错位轮的
> rb_erase 附带写入打烂了 selinux_state，SELinux 子系统崩坏 → binder
> 级联 EINVAL → system_server 楔死 → 冻结。** 每一环都有实证。

---

## 一、证据清单（全部原始文件亲读）

| 证据 | 内容 | 指向 |
|---|---|---|
| A1_2.out（冻结轮） | **exploit 本体干净跑完**，尾行 `mt22: done wrote=0`；六发全 errno=110；`[-] slide bad leaked pointer=e0451a903f4b9e2e` | 冻结不在漏洞关键路径内，在系统层 |
| arc_log.txt | round2 start 20:41:22 后**无结果行** | 设备在 round2 窗口内冻结 |
| run_arc.sh | `sleep 2` 轮距、无沉降、无内存门、无残留检查 | 我要求的护栏一个都没实现 |
| pstore 尾部 4000B | `SELinux: ... Called before initial load_policy on unknown SID 2333` + binder 连续 `transaction failed -22`，时间戳 ~1103s（boot 后 18 分钟）| ★决定性★ 见下 |

## 二、决定性证据的解读（为什么它改写一切）

pstore 里那条 SELinux 消息**正常只在开机早期（策略加载前）出现**。
在 1103 秒 uptime 打出来 = 内核认为 `selinux_state.initialized == 0`。

**谁会把 initialized 写成 0？** 我们的 ENF 写几何瞄准的就是 selinux_state
一带（TREE_PC=ffffff8002a41b90，胜局 = 写 enforce 位）。**几何错位的
ENF 轮，rb_erase 的写入落在 selinux_state 附近但偏了——打中的不是
enforce 而是 initialized/邻域。**

SID 2333 = 垃圾值（内核合法 SID 只有几十个）——安全上下文被附带写入
打烂后算出来的废数。binder EINVAL 级联 = LSM 钩子在非法上下文上全面
失败。system_server 楔死 = UI/触控全灭 = 用户看到的黑屏。

## 三、完整因果链（每环有证）

```
新 boot 未沉降 + ARC 轮距 2s + round1 被 timeout SIGKILL（毒树拆解中）
→ round2 喷页与 round1 退出拆解迎头相撞，喷页格局被污染
→ 几何错位（A1_2 读回 e0451a903f4b9e2e = 高位无 0xffff 内核签名）
→ 六发 rb_erase 全部失瞄，附带写入散落 selinux_state 邻域
→ selinux_state.initialized 被打成 0（pstore 铁证）
→ SID 计算失败 "unknown SID 2333"（pstore）
→ binder 事务级联 EINVAL（pstore）
→ system_server 楔死 → 冻结零打印 → 用户长按（PMIC 复位）
→ 复位时 f2fs 未 checkpoint 的页丢失（A1_1.out 全 NUL + dsh 污染同类）
```

## 四、为什么之前 16 轮 ENF 没冻

几何握住的轮次（读回指针正常），写入全部落在良性靶位——安全。
**危险的不是 miss，是"错位 miss"（读回垃圾）**。今天三次冻结全部
发生在 ARC 紧凑序列里（2s 轮距 × 击杀余波 × 新 boot），错位概率被
人为放大。手动轮 0 冻结与此完全一致。

## 五、账目修正

1. 假设 A（负载活锁）**出局**——A1_2 的 .out 证明 exploit 自己跑完了，
   且 pstore 有明确的子系统级联死亡痕迹，不是无差别的饿死
2. dsh 污染机制落定：附带写入 / 硬复位丢页二选一（hang#1 的污染 =
   附带写入打中 FS 元数据的运气；A1_1 全 NUL = 丢页），与"事故类型"
   无关——现场上一份修正是对的
3. "冻结无解释"正式结案：不是没有解释，是解释在 pstore 里躺了一晚上

## 六、明天怎么办（纪律升级，策略不变）

**首选仍是 Enforcing 直打 R**（沉降 ≥10min、手动单轮、间隔 ≥120s）。
R 的 PTR 几何写 task+0x778 邻域——错位轮的爆区在 task 结构附近而非
selinux_state，冻结模式不同且历史上 mt53/54 下无系统级死亡。风险
如实说：**错位轮的附带写入无法归零，只能压概率**（沉降 + 间隔 +
击杀后查残留就是压概率）。

**新纪律（每轮后立即，零成本）**：
```sh
grep -a "bad leaked pointer" /data/local/tmp/<本轮>.out
```
- 出现 = **脏轮**：本轮几何错位过，系统可能带暗伤——下一轮推迟 5min，
  先 `getenforce` + `ls /sys/fs/pstore` + dsh 健康检查，无恙再继续
- 不出现 = 干净 miss，按正常间隔继续

**mt57 提案（明天白天决定，今晚不写代码）**：现在一次 pselect 窗口内
连发 6 发（`calls=1`）。改成**逐发窗口 + 发间几何自检**（fdset 里埋
已知 canary，每发后读回验证，canary 错位即中止剩余弹）——把错位轮的
暴露从 6 发降到 1 发。工程量中等，收益 = 冻结风险数量级下降。

## 七、给现场的三句话

1. 冻结机制已定案，别再当悬案挂着——pstore 尾部就是验尸报告
2. 明天 R 直打照旧，每轮后 grep `bad leaked pointer`，脏轮停 5 分钟
3. mt57 明天评审后再动手，今晚谁都不许再改代码

—— 评审 · 四份证据闭环：错位 ENF 轮 → selinux_state 附带损伤 →
SELinux/binder 级联 → system_server 楔死。ARC 的 2 秒轮距是放大器，
纪律就是拆除放大器
