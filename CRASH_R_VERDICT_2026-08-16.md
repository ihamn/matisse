# R 轮崩溃裁定 + mt56 修复（评审，2026-08-16 深夜·第四班）

> 三问全答。**先说结论：这次崩溃是项目里程碑，不是挫折——R 落地成功了。
> 你们 pstore 抓到的栈本身就是写入成功的证明。死因是假 cred 一个字段
> 偏移错 8 字节，mt56 已修。**

---

## 〇、最重要的事先说：账本重写

崩溃栈 `selinux_task_to_inode+0x58` 的第一行有效指令链（ELF 反汇编）：

```
+0x38: add x8, x0, #0x778     ← 取 task->real_cred 的地址
+0x3c: ldar x8, [x8]          ← x8 = task->real_cred ← ★STAGE-R 换入的指针★
+0x40: ldr x8, [x8, #0x78]    ← x8 = real_cred->security
+0x58: ldr w22, [x8, #4]      ← 读 tsec->sid ← 崩在这, far=0x4
```

`far=0x4` = NULL+4 = security 读到 NULL。**而 security 为 NULL 的唯一
原因：real_cred 指向的是我们的假 cred，且假 cred 的 0x78 处没写值。**

⇒ **STAGE-R 写入落地 + 存活到 open() = 项目第一次 PTR win + win 后
活着走出 futex 上下文。** 账本：PTR 3 轮 3 win（100%），死因演化 =
毒树 walk（crash#2/#3）→ **假 cred 字段**（本次）。mt53 跳 unlock、
mt54 waiter 超时拆除、静默纪律——**全部生效，没有一次死在 rt_mutex**。

## 一、你们的 Q1：+0x58 解引用什么（已钉死，三源铁证）

| 源 | 指令 | 结论 |
|---|---|---|
| selinux_task_to_inode+0x40 | `ldr x8,[x8,#0x78]` | **security@0x78** |
| selinux_capable+0x44 | `ldr x9,[x0,#0x78]` | security@0x78（独立二源） |
| cap_capable+0x04 | `ldr x8,[x0,#0x88]` | user_ns@0x88 |
| cap_task_fix_setuid+0x64/68 | `stp xzr,xzr,[x0,#0x30]; str xzr,[x0,#0x48]` | caps 五连=0x30-0x50 |
| cap_task_fix_setuid+0x28 | `ldr w8,[x8,#0x24]` | securebits@0x24 |

本内核 cred 真布局（usage 8B）：
`0x00 usage | 0x04-0x20 九个 id | 0x24 securebits | 0x30-0x50 五组 caps | 0x58-0x77 keyring(须 NULL) | 0x78 security | 0x80 user | 0x88 user_ns | 0x90 group_info`

## 二、你们的 Q2：blob 有什么问题——不是 blob，是指针位置

mt35 假 cred 把 security 写在 **0x80**（真值 0x78），user@0x88（真
0x80），user_ns@0x90（真 0x88），group_info@0x98（真 0x90），caps
写在 0x38-0x58（真 0x30-0x50）——**整个指针/caps 区系统性右移 8 字节**。
08-15 的《cred内部偏移_反汇编真值》文档早就标了 `CRED_SECURITY_OFF=
0x80 ❌ 可能 0x88`，但 mt35 布局一直没回头修。今晚它收账了。

附带拆除的第二颗雷：旧布局 cap_ambient 写在 0x58 = **keyring 区被写成
非 NULL 伪指针**（任何 keyctl/进程退出碰 keyring 都会炸）。mt56 一并清零。

blob 本身（payload+0x3900, osid/sid=SECINITSID_KERNEL）没问题——
崩在"找不到 blob"（指针 NULL），不是"blob 内容错"。

## 三、你们的 Q3：修方向 = 修字段，不是避开 open()

**避开 open 做不到**（进程活着就会 open /proc：子进程监控、CapEff 轮询、
mt51 发间检测……全是 open）。而且不应该避：正确的假 cred 必须能扛住
任意 selinux hook——这是"换 cred"方案的定义要求，不是副作用。

**mt56（已推，util.c）**：按上面真值表重写整个假 cred——caps 移到
0x30-0x50，keyring 区留 NULL，security→0x78，user/user_ns/group_info
各左移 8。ids 区全 0 本来就对（memset 兜底）。

## 四、下一轮（新 boot，Permissive 已丢）

顺序不变，配方不变，唯一变化 = 重编带 mt56：
1. **A1**（胜局配方，预期 1-2 轮内翻 Permissive；顺带确认新 boot 底座）
2. **R**（同 REPAIR_ROUND 配方 + mt56 重编；`PTR_RIGHT=auto` 标记照查）
3. **C**（R 落地后 8 分钟窗口内）

判读变化一条：**R 后存活 60s 且 CapEff 满 → 不急着 C，先看 root_alive**
——上次 R→crash 的间隔里能拿到多少存活数据就记多少（父 shell 轮询
/proc/<child>/status 的 CapEff——注意这次它不再崩，mt56 修的正是它）。

## 五、待办

- **rep_R.out 推仓库**（确认 `[PTR_RIGHT auto=spray_fake_cred]` 标记在
  崩溃前出现 = auto 地址链路闭环；顺带看 win 时序）
- B1 跑了没有？如果跳过了，下轮 A1 就当 B1 用（同 env 同二进制）

—— 评审 · mt56 已推 · 假 cred 从"猜的布局"变成"反汇编布局"
