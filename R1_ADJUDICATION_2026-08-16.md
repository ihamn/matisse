# R1 即时裁定（三问快答，5 分钟倒计时内用）

## Q1：ret=0 是否意味着 erase 命中？—— 不是

`LOCK_PI ret=0` 证明的是：**毒树 walk 发生了、锁状态被改变**（写原语
确实触发）。它不证明写落在了 PTR 目标（task+0x778）。

铁证就是本轮自己：ret=0（walk 发生）+ CapEff=0（没换 cred）——
**触发了但打歪了**。R 轮落地的唯一确认标准始终是 CapEff 满帽 /
child status，ret=0 只是必要条件不是充分条件。

历史对照：前 3 次 R 轮 ret=0 → 全部 crash 在 selinux hook（= 写命中
real_cred → 换 cred → hook 消费）。这次 ret=0 → CapEff=0 无 crash
（= 写打歪到无害处）。同一签名两种结局，证明 ret=0 本身不携带落点
信息。

## Q2：dirty 判定在 PTR 轮的语义？—— 完全适用，且更严格

`bad leaked pointer` 是 slide.c:536 的**读回几何检查**（泄漏指针高位
≠ 0xffff = 废），检查的是 fdset 栈布局本身——ENF 和 PTR **共用同一套
布局**，与轮型无关。dirty 的含义统一：本轮几何失准 → 读和写的落点
都不可信。

本轮三角互证就是证明：dirty（几何失准）+ ret=0（walk 发生）+
CapEff=0（写没中目标）——三个信号讲的是同一个故事。纪律照旧：
dirty = 5min 停 + 系统检查。

诚实说明：这次打歪没崩是**运气**（落点无害），不是"PTR 失准安全"。
打歪可能落在 task 结构任意字段——CapEff=0 只是这次没中，不是没险。

## Q3：R2 时机 —— 5min 等满即打，零改动

- 5min 等满 + `getenforce` + dsh 检查无恙 → **R2 立即，配方零改动**
  （dirty 是概率性几何失准，历史 R 轮 3/3 命中，1 次 dirty 不构成
  改配方的理由；时间窗口也不允许调参重标定）
- **dirty 预算 1/2 已用**：R2 再 dirty = 直接收工推证，不跑 R3
- perf 泄漏本轮成功（有 futex trigger 行 = 走过了 main.c:754 护栏）
  —— Enforcing 直打路线本身成立，继续

## 本轮正面资产（别只看没中）

1. **mt53 静默窗首次实弹验证成功**：WIN 后跳 unlock → 尾弹 errno=35
   （EDEADLK fast-fail，不再进树操作）→ boot 存活。这是新防线第一次
   在真实 win 下工作，此前从未验证过
2. Enforcing 下 perf 泄漏通过 = 直打路线的自探测假设被证实
3. 打歪一次系统无恙 = 可以继续用剩余预算

## R2 起飞命令 = 总册§二原样（mt58 已在位）

时间纪律不变：T+75 硬停。R2 结果三类走向照判读表。

—— 评审 · 快速通道 · R1 记账：walk ✓ 静默窗 ✓ Enforcing 路线 ✓
落地 ✗ 几何 dirty —— R2 决定今晚成色
