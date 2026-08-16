# R5 判读（评审侧）2026-08-16

## 总判决

**mt60 唤醒修复完全生效，全链首次确定性跑通；trigger 0 ret=0 胜利形态复现 R1；
但 R 写（real_cred）未落地（机载判据实锤）；rc=255 根因定位 = main.c:966
pr_error("no root") 内嵌 exit(-1)，非二进制污染（预注册绊线解释修正）。**
下一步 = 原配方重掷 R6 + 门槛命中即补 C 轮（mt48 两轮换指针协议的下半场，
历史从未执行过）。卡 3 已发。

## 逐行判读（对照 R5_PRE_ADJUDICATION 预注册表）

| 行 | 实测 | 预注册预测 | 判定 |
|---|---|---|---|
| `pre-requeue words f_wait=0 target=5123 chain=2147488770` | f_wait=0 | 预测 f_wait=1 | **我的 FACT 4 前提错了**，见下 |
| `waiter FWRQ ret=-1 errno=110 wake_secs=3` | 停泊 3s 超时醒 | 预测 errno=110 | ✅ 唤醒理论成立，mt60 核心修复实证 |
| `waiter UNLOCK_PI(chain) ret=0` | 干净释放 | — | ✅ 死锁解除 |
| `owner chain LOCK_PI ret=0 (woken)` | owner 被唤醒拿到 chain | 预测"阻塞中不可见" | 偏差但更优：owner 被 waiter 的 UNLOCK_PI 唤醒，拓扑完美闭环 |
| `mt25: futex trigger 0 ret=0` | 写原语开火 | — | ✅ WIN 形态，与 R1 逐行一致 |
| `triggers 1-5 errno=35` | 环持续 | — | ✅ 符合 EDEADLK 终态语义 |
| `CapEff=0 × 全部心跳` | real_cred 未换 | — | ❌ **R 写未落地**（判据见下） |
| rc=255 | — | 预注册"二进制污染绊线" | **修正**：真因 main.c:966，见下 |

## FACT 4 正式关闭（含自我勘误）

我此前断言 "errno=35 要求 curval==1（futex.c:2006 cmpval 检查）"——**读错了参数**。
实际调用（slide.c:676）：`futex_op(&f_wait, CMP_REQUEUE_PI, 1, (void*)1, &target, 0)`
经 util.c:156 展开为 `futex(uaddr, op, val=1, timeout=(void*)1, uaddr2, val3=0)`：
- `val=1` = **nr_wake**（不是 cmpval）
- `(void*)1` = **nr_requeue**
- `val3=0` = **cmpval** —— f_wait=0 恰好通过

**不存在"神秘写 1 者"，从未存在。** errno=35 全程由已证机制产生：
waiter 停泊 f_wait（errno=110 实证停泊）→ requeue 代理夺锁 target（owner 持有）
→ PI 环走查（owner 阻塞 chain，chain 属 waiter）→ EDEADLK。
pre-requeue 三词与拓扑完全自洽：target=5123=owner TID 干净持有；chain=0x80001402
=waiter TID 5122 | FUTEX_WAITERS 位 = owner 已排队。

## bad leaked pointer = 本路由固有噪声（非失准信号）

值 9c4fd468b54d5fb5 = 真 boot_id（b55f4db5...）前 8 字节 LE —— sysctl 从未中毒，
**读回的就是原样 UUID**。历史对照：R1（胜利形态轮）同值同现；A1_2（未赢轮）同现。
slide_read_stext 是遗留泄漏通道，MTK 路由（slide 硬编码 0）从不依赖它。
R1 时代把它标 "dirty 几何失准" 是误标，正式降级为噪声。

## R 写未落地的机载实锤（不是推测）

main.c:719-728：mt33 子进程**每 200ms** 把自身判据写进
`/data/local/tmp/mt49_child_status.txt`（`task= uid= euid= CapEff= root_seen=`），
且心跳行 `mt47: alive poll=N uid=2000 CapEff=0000000000000000` 从 poll=50 到
1200 全程 CapEff=0。status 的 CapEff 读 **real_cred**（main.c:626 注释实证），
R 轮 STORE 目标恰是 [task+0x778]=real_cred。若落地，CapEff 必翻满帽。
**未翻 = STORE 没打中 [task+0x778]**。与 R1 行为一致（R1 时代同未翻）。

## rc=255 根因（预注册表修正）

main.c:966 `pr_error("mt28c: no root after %d attempts")` —— pr_error 宏
（kernelsnitch/utils.h）内嵌 exit(-1)。父进程在 no-root 收尾处以 rc=255 退出，
**子进程不受影响**（孤儿化继续 8 分钟窗口——R5 尾部 24 条心跳即子进程所打）。
mt60 只修了 STALL 路径的 pr_error，收尾路径这颗还在。**纯 cosmetic**（轮已结束，
退出码不影响任何行为），mt61 再修，不阻塞协议。

## rc 语义表（更新）

| rc | 含义 |
|---|---|
| 0 | 父进程干净走完（无 cred 路线时） |
| 42 | **子进程见到 ROOT**（root_seen 落地） |
| 2 | 子进程 8 分钟窗口耗尽未 root |
| 255 | 父进程走完未 root，收尾 pr_error 退出（= 本轮"正常未中"） |
| 3 | mt60 watchdog 哑轮自弃（12s） |
| 124 | harness 击杀真挂 |

## 状态台账

- 编舞（choreography）：**已解决**。R5 = mt59 握手 + mt60 唤醒 + EDEADLK 形态
  三合一确定性复现，连续第二轮无哑轮（R4 哑、R5 全链）。
- 剩余问题 = 台账旧两件：**落点**（STORE 未中 [task+0x778]，历史成功率非零：
  mt25 时代 selinux 写落地过；mt32-36 时代 C 写落地过 7 次——都证明落点可达）
  和**消耗**（落地后 fake cred 消费，协议已备）。
- R5 预算消耗：0 dirty / 0 freeze（无崩、无冻结、boot 存活推文为证）。
- ANR 证据：现场两弹均未推（step2 未执行），降优先级，卡 3 再挂一次。
