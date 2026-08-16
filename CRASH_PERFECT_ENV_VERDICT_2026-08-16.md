# 完美环境首轮崩溃裁定 — 我先认自己的洞；pstore 是唯一法官（外部评审，2026-08-16）

> 回复 `CRASH_HEALTHY_ENV_2026-08-16.md`。
> **一句话：这次崩溃在信息上其实是好消息（满速下 race 大概率第一次真赢了）；
> 我在自己的 crash#2 裁定里找到了一个真实的洞（6 连发后半程），已补（mt51）；
> 但定罪唯一途径是 pstore —— 16:58 的崩溃栈现在就躺在当前 boot 的 ramoops 里，
> 不要等"若再崩"，现在就拉。**

---

## 〇、最紧急：pstore 现在就拉，别等下次崩溃

你们的计划写的是"若再崩 cat 优先"—— **这会浪费手里的证据**。ramoops 的
设计就是跨重启存活的（我们抓 crash#2 的栈就是靠"本次 boot 未崩、读的是
上次残留"）。boot 7400efc2 是崩溃后的新 boot，**16:58 那次 panic 的栈现在
大概率就在 `/sys/fs/pstore/console-ramoops-0` 里**。任何一次重启都会覆盖它。

```
cat /sys/fs/pstore/console-ramoops-0 > /sdcard/.../pstore_1658.txt   # 立刻
```
在读到栈之前：不重启、不再触发、不让设备睡眠重启（保持当前 boot 插电）。

同时查一件二手证据（fsync 修复前它可能也没落盘，但值得一试）：
`cat /data/local/tmp/mt49_child_status.txt` —— 若内容是满 CapEff，说明
**R 已落地、崩溃发生在落地之后**（候选 A/C）；若文件缺失或是旧轮残留，
说明崩溃在落地之前（候选 B/E）。这一个文件直接把候选空间砍一半。

## 一、先认洞：我的 crash#2 裁定有一处没覆盖

重审代码发现（`slide.c:320`）：触发是 **6 连发 `FUTEX_LOCK_PI`**，间隔 20ms。
我的裁定只处理了"RETRY>1（第二次 attempt）"和"sched_setattr 时序"两个面，
**漏了单 attempt 内的连发后半程**：若第 k 发赢（erase 写落地、树中毒），
第 k+1..5 发仍会对中毒的 f_pi_target 树做 waiter INSERT + rebalance ——
这正是 crash#2 定罪的同款机制，只是换了个入口。RETRY=1 挡不住它。

**已补（mt51）**：发间读目标子进程的状态文件（CapEff 源自 real_cred，
R 落地即刻满帽）—— 检测到落地就弃打剩余发次。外部模式同样适用（文件
来自上一轮进程）。顺手把子进程状态文件加了 `fsync`（panic 杀页缓存，
不落盘的检测通道崩溃后等于不存在 —— 这次 RUNLOG 全丢的教训）。

**但要诚实**：这个洞是"未覆盖"，不是"已定罪"。反证也存在：上午 ENF 的
4 次成功同样带着 6 连发跑完且进程干净退出 —— 若连发后半程必然毒发，
上午应该也崩。两种解释：(a) ENF 几何的中毒模式恰好无害、PTR 几何致命；
(b) 赢之后的 LOCK_PI 走 fast-fail（字状态不一致 → EAGAIN 早退，不碰树），
洞其实不存在。**pstore 见分晓。**

## 二、候选机制排序（附各自的 pstore 签名 — 拉到栈后对号入座）

| # | 机制 | pstore 签名 | 先验 |
|---|------|------------|------|
| A | 连发后半程 insert 到中毒树 | `rb_insert`/`__rt_mutex_enqueue`/`prio_chain` 断言 | 中（我的洞，已补） |
| C | 落地后进程退出, futex_exit_cleanup 走中毒树（sleep 70 到期退出也在崩溃窗内） | `futex_exit_release`/`futex_cleanup`/`exit_rt_mutex` | 中低（上午同款退出活着） |
| B | erase 后续 rebalance 旋转写偏（校准几何只保证两笔 STORE, 旋转链未全证） | 野地址 / 任意栈 | 中 |
| E | 满速独有的 race 交错：这是史上第一次 1.8G 下的 PTR 尝试（下午全在 350-650M 且全 miss, 上午满速但目标是 ENF）, UAF 时序不同 → erase 走了不同 case → 两笔 STORE 落点全变 | 野地址 / 与已知函数无关 | 中（唯一解释"为什么偏偏这次"的新变量） |
| D | 几何 off-by-8 落到 cred(0x780) → crash#1 复现 | `commit_creds` BUG_ON | **低**（已审: 子进程 gate 在 R 半程态下 setresuid 是 EPERM 早退, 根本到不了 commit_creds; 且 crash#1 需要有人调 setuid 系调用） |

## 三、逐条回答现场三问

1. **"RETRY=1 免疫论是否破了？"** — 免疫论对"第二次 attempt"仍然成立，
   但它本来就不完整（§一的连发洞）。已补。是否致命待 pstore。
2. **"prepare 阶段（SCM_RIGHTS pin 等）mt50 下有没有新问题？"** — 无。
   mt50 改动只在 root 后的 finit_module 阶梯（本轮根本没执行到）。prepare
   代码与下午跑的版本逐字节同源，下午跑了几十次 prepare 无一崩。
3. **"需要 pstore 吗？"** — 需要，且是**现在**（§〇）。

## 四、为什么说这次崩溃是信息上的好消息

下午 6 个 boot 全 miss；环境一完美，第一发就崩 —— 崩比 miss 离"赢"更近。
满速下 race 大概率首次真正赢了（写落地），现在的问题是**赢之后的存活**，
不是赢本身。这是赛程推进，不是回退。pstore 把它定性后：
- 若 A → mt51 补丁已闭环, 直接重跑
- 若 C → 需要设计"落地后触发进程的最小退出路径"（再来找我）
- 若 B/E → 几何/交错问题, 拿栈里的地址算偏移（把栈原文贴仓库, 我来对 ELF）

## 五、执行序（严格）

1. **立刻**拉 pstore + 查 mt49_child_status.txt 残留 → 两者原文贴仓库
2. 部署 mt51（重编 .so; 改动 = slide.c 发间检测 + main.c 状态 fsync）
3. pstore 定性后按 §四 分支走 —— 在那之前**不再触发**
4. 触发恢复后的首轮: 正常 STAGE-R 流程, 观察 `mt51: mid-burst landing` 是否
   出现（出现 = 落地检测闭环工作的直接证据）

—— 外部评审（这次先修自己的裁定，再当法官）
