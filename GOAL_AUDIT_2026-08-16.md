# 目标审计 — "我们现在的目标对了吗"（外部评审，2026-08-16）

> 用户（监工）今日收盘提问："我们现在的目标对了吗？这个问题得想想。"
> 拆成三层审计：**终极目标 / 路线目标 / 战术目标**。结论先行：
> **终极 ✓、路线 ✓（今天补上了"为什么不是别的路线"的正面证明）、
> 战术 ✗ 已过度投入（环境战线该收束了）。外加一个诚实的核心风险清单。**

---

## 一、终极目标：KernelSU root ✓（不变）

`insmod android12-5.10_kernelsu.ko (v3.2.5)` 是合理终点：systemless、重启
可重放、不碰分区。没有更便宜的替代终点。

但终点链条上有一个**从未被验证的假设**，今天必须点名为第 3 号假设：

| # | 终点链条假设 | 状态 |
|---|-------------|------|
| 1 | 双写后 setresuid → 全套 root | 设计闭环（BUG_ON 已按 commit_creds 反汇编论证） |
| 2 | kernel SID → setenforce 合法 | 已论证（sel_write_enforce 只查 SID） |
| 3 | **kernelsu.ko 能 insmod**：vermagic 匹配 `5.10.209-android12`（MTK 构建后缀可能不同）+ 符号 CRC 不校验 | **未验证**。官方 android12-5.10 构建 ≠ MTK 5.10.209 构建，vermagic 字符串不匹配会被 `do_init_module` 拒（除非 force）。**ask：现场 `strings kernelsu.ko | grep vermagic` 一行命令验证**，早于 STAGE-C 之前做，别等 root 到手才发现 insmod 被拒 |

## 二、路线目标：cred 指针双写 ✓（今天补上正面证明）

一直缺一个论证："为什么不是 modprobe_path 那类经典一字段路线？" 今天用
指令级证据补齐 —— **不是没想过，是几何上全部死刑**：

```
写原语是绑死的一对（ELF_ANALYSIS + TASK_ADJUDICATION 已证）:
  STORE(a): [parent+8] = child     ← 想写的目标
  STORE(b): [child]     = pc       ← child 的值必须本身是合法可写地址!

字符串型全局 (modprobe_path / poweroff_cmd / core_pattern):
  要写的值 = "/tmp/x\0" (0x00782f706d742f) — 不是合法地址
  → STORE(b) 写它 → panic。几何死刑, 全排除。
  (实测: modprobe_path@0xffffffc00a7b0e78="/sbin/modprobe",
   __request_module+0xb0 动态读它, 无 STATIC_USERMODEHELPER —
   机制本身活着, 但我们的原语够不着)

Case-1 (right=0) 只能写 0:
  → 恰好够写 selinux_state.enforcing=0 (mt26 已验证落地)
  → 但 0 值拿不到 caps (caps 在 cred 里), 不构成 root

结论: 在"值必须是合法指针"的几何约束下, 唯一能一次写换成
"高价值内核对象指针"的家族就是 cred 指针 (init_cred)。
STAGE-R/C 双写是约束下的最优解, 不是偏好。
```

（连带排除：一次写两个 cred 字段 —— MT49_ADJUDICATION Q4 已几何判死；
cred 内容就地改 —— 多字段多次写，更多触发轮，劣于两写换指针。）

## 三、战术目标：环境战线 ✗ 过度投入，即刻收束

今天下午 5 份文档全在修环境（崩溃定罪→冷却→热→joyose→功耗）。审计结论：

1. **环境问题上午不存在**（同一设备同一 .so，上午 4 连成功）
2. 明天冷态+满电+充电器+perflock，环境变量大概率自愈
3. 环境战线的边际收益已归零：freqgate v2 + 诊断清单已覆盖所有已识别机制，
   **再写第 6 份环境文档 = 给不再存在的问题打工**

**收束纪律：下一 session 只做既定动作（诊断 2 分钟 → perflock →
SKIP_R0 全套），不再展开新的环境调查线。数据（logenv）自动记录，
若再灭让数据说话，不预先推理。**

## 四、诚实的核心风险：双写路线从未被干净测试过一次

审计全部 16 次实验：**没有一次是"两写都有机会落地"的干净尝试**——

- mt48（进程内 ALT）：死于 crash#2（同进程二触），R 落地了 C 没机会
- mt49 下午 6 boot：全部死于环境（触发都没成），不是路线问题
- 上午成功 boot：只跑到 ENF，PTR 从未起跑

所以"路线对不对"目前是**论证对、数据零**。这是当前项目最大的信息缺口，
也是明天第一优先级的全部意义：**一次干净的全流程尝试比任何新分析都值钱。**

## 五、明日决策树（一次干净尝试后按叶子走，不再开会）

```
冷态+满电+perflock, SKIP_R0=1 全套:
├─ STAGE-R 4轮全灭(环境正常) → 停, 报数据(logenv+runlog), 等审几何
│    (此时才重新考虑 PTR 几何校准, 但要警惕: 20-40%×4 灭概率 13-41%,
│     先排除是否又逢环境窗, 用 logenv 判)
├─ R 落地, C 4轮不落地 → 外部模式链路问题(PSELECT_TASK/env/状态文件),
│    贴 runlog 逐行审, 大概率小 bug 不是路线问题
├─ 双写落地, gate 不亮 → task 地址/字段偏移问题, 报状态文件内容
├─ root_alive ✓, insmod 失败 → §一第 3 号假设(vermagic), 现场
│    strings kernelsu.ko | grep vermagic → 不匹配则需 force 或重编 ko
└─ ksu_done ✓ → 项目毕业, 写终局报告
```

## 六、总结陈词

- **目标没有错**：终极（KSU）合理、路线（cred 双写）是几何约束下的唯一
  解（今天补齐正面证明）、修复史（crash#1/#2）全部闭环。
- **错的是注意力分配**：下午 4 小时花在了上午不存在的问题上。
- **明天唯一重要的事**：一次干净的 mt49 全流程。它同时检验路线、外部
  模式、gate、终点链条四件事。

—— 外部评审（这次把"为什么不是别的路"也钉死了）
