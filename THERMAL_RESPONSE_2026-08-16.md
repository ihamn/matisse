# 热降频应对方案 — 不改时序参数；freq 闸门 + ENF 撤编 + 两项 ask（外部评审，2026-08-16）

> 回复 `INCIDENT_LOG_2026-08-16.md` checklist 第 4 条（"对面是否已根据热降频
> 数据调整时序参数"）及现场待机问题。
> **一句话：时序参数一律不动。上闸门（joyose clamp 自动检测+自动 force-stop）、
> 下 ENF（已冗余且正是 15:30 的崩点）、先拉 pstore。**

---

## 一、时序参数为什么不动（SLIDE_CONSUME_USEC 保持 0）

 reconsider 过我自己的热窗机制，发现它**只对了一半**：

```
common.h:55  CORE=0 (pselect/waiter/owner)
common.h:125 CONSUMER_CORE=1
D9000 布局:  cpu0-3 = A510 同簇
实测:        freq0 与 freq1 恒等 (1.8G→650G 同步) ← 现场数据自证同簇同频
```

关键：`slide.c:270` 的 consumer 窗口是 **2000 次 yield 的纯指令循环**
（不是 usleep），窗口长度以**周期数**计，不以微秒计。同簇统一降频时，
pselect 侧（cpu0）和 consumer 侧（cpu1）**等比变慢**，周期级交错保持不变，
race 校准依然成立。所以"650MHz 窗口漂移"在**稳态 clamp** 下并不必然成立。

真正破坏窗口的是**变频瞬态**（1.8G↔650G 切换瞬间两核不同步，2 分钟内
现场恰好观察到一次全速→1/3 的切换）和跨簇异步。这两种情况的对策都不是
重新校准，而是**消灭条件**：保持 clamp 关闭、频率贴顶，原校准继续有效。

另一条硬理由：**数据只有一对**（15:28 全速 / 15:30 clamp）。拿单对观测去
调参 = 追噪声。而且 15:4x 那轮 STAGE-R 是在 joyose 已 force-stop（全速）
下跑的，4 轮未落地 —— 全速也 miss，进一步说明"为 clamp 重校准"没有依据。

## 二、闸门（脚本已加，shell-only 无需重编 .so）

盯 `scaling_max_freq` 而不是 `scaling_cur_freq`：joyose 的 clamp 表现为
**max 被压低**（负载再大也上不去）；而空载时 cur 低是正常调频、无害。
- 每轮触发前 `freqgate()`：cpu0/cpu1 的 max < 1.5GHz → 自动
  `am force-stop com.xiaomi.joyose` → 复查 → 仍 clamp 则跳过该轮（记日志）。
- 重启后 joyose 回来的问题顺带解决：闸门每轮自检，不用人工 checklist 记着。

## 三、ENF 触发轮撤编（`ENF_ENABLE=1` 可回滚）

15:30 崩的正是 ENF round2 —— 今天唯一一次 ENF 崩（历史 16 次实验里 ENF
从未崩过）。而 ENF 现在是**纯冗余**，证据链全部来自你们自己的档案：

1. `MT47_ROUTE_DECISION` 第 22 行：`sel_write_enforce` @0xffffffc0088cf774
   **连 capable() 都不调**，只查 `avc_has_perm(cred->security 的 SID)`；
2. 同文件第 42 行：init_cred 的 `+0x78 security` 运行时指向 **kernel SID**；
3. STAGE-C 落地后主观 cred = init_cred → SID = kernel_t → setenforce 合法；
4. main.c:896 子进程本来就有 "mt28g: 顺手 setenforce 0"。

即：**root 到手瞬间，SELinux 由子进程自己翻**，零触发成本、零崩暴露。
老的"用户态 setenforce 不可靠"结论只对 untrusted SID 成立，对 kernel SID
不适用。ENF 轮从主线撤下，只留回滚开关。

## 四、两项 ask（下次跑前做，第 1 项零成本且急）

1. **立刻在 boot 79737542 上拉 pstore**：`cat /sys/fs/pstore/console-ramoops-0`。
   ramoops 跨重启存活，15:30 那次 ENF 崩溃栈大概率还在。这直接检验我的
   prio_chain 免疫裁定：若又是 `rt_mutex_adjust_prio_chain+0x1788`，说明
   RETRY=1 免疫论有洞要补；若是新栈，则是新信息。**在被下次重启覆盖前拉。**
2. **dsh 归因修正**：INCIDENT_LOG 里"写原语副作用落到 dsh 存储文件 inode"
   的结论**不成立** —— 写原语只写内核地址（task/selinux_state 区），
   从几何上够不到用户文件 inode。dsh cache 是高频写文件，panic 未清盘
   导致的 FS 元数据损伤才是 parsimonious 解释（三次复发均伴随内核崩溃，
   时间吻合）。修正它，避免留下"原语会打用户文件"的错误信念。

## 五、下次 session 执行序

1. 拉 pstore（第四节第 1 项）→ 把栈贴仓库
2. 换新 boot（79737542 已耗 4 轮 STAGE-R + 2 轮 ENF，预算近半且带崩史）
3. 稳定 5-10min（你们 checklist 已有）→ `SKIP_R0=1 sh test_mt49_root.sh`
4. 流程现为：R0(默认跳) → ~~ENF~~ → STAGE-R(×4, freqgate 护航) →
   STAGE-C(×4) → 子进程 setenforce + finit_module
5. 判读里程碑不变：`STAGE-R LANDED` → `ROOT-ALIVE` → `KSU-LOADED`

今天设备崩了 3 次、热、疲劳 —— 同意用户叫停。休息，下一 session 冷态起步。

—— 外部评审（这次连该盯 max_freq 还是 cur_freq 都替你分好了）
