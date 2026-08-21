# R9 判读（评审侧）2026-08-21

## 总判决

1. **R7 的"内核卡死"假说被证伪**：R9 在全新 boot（`0ccbcac1`）、
   取证零残留的干净环境下，sched **秒回成功**（`mt19b: sched
   attempt=0 tid=22890 ret=0 errno=0`）——不是卡死，是**迟到**。
2. **新阻断点定罪（第三环真身）**：consumer 风暴**整体掉出 2 秒
   pselect 窗口**。证据：`calls=1` 在窗口内（自旋段仍占核），但第一个
   mt19b 打印出现在 `pselect returned` 行**之后**，6 发触发全部跟在
   后面——风暴只在 fdset 帧已消亡后才开火 = erase 从未在帧存活期间
   被触发 = **写结构上不可能**。
3. **根因 = 环境负载 × 2s 死值窗口**：开火前取证实测负载
   16.02/15.96/15.43（16 核全饱和）、**零残留进程** = 纯 MIUI 环境负载，
   不是我们进程的锅。consumer 是 SCHED_NORMAL shell 线程：
   自旋段占核没问题（calls=1 达成），但 `usleep(50ms)` 睡醒后要重新
   排队——饱和运行队列上唤醒→上核延迟以秒计，风暴被整体推迟到窗口
   关闭之后。R7 与 R9 同签名（两轮都在 LOAD_WAIT 负载下开火）——
   这不是竞态随机性，是确定性机制。
4. **修复 = mt61（窗口 2s→20s 默认，`PSELECT_WINDOW_SECONDS` 可调）**，
   已构建交付（`bin/mt61/preload.so`，SHA256
   `19e8f6369ec22a262aeb92d955e5f41636c8776bda1aa8ac81588661c1ad201d`，
   9/9 标记验证，bionic 依赖干净）。依据：A1_1 WIN 轮窗口 held 满
   整个 harness 时长 = 长窗口与胜利形态兼容；fdset 帧在 waiter 私有
   内核栈，加宽无跨任务暴露面。
5. **负载门槛降级为纯记录**（用户现场反馈成立）：手机日常态负载从不
   低于 3，该闸永远走 override 分支 = 只浪费时间；轮间负载闸今天还
   拦掉了 R10 重掷。v4 起 load 只打印不拦截（boot/Enforcing 闸保留）。
   20s 窗口本身就是对负载的吸收——被推迟 5 秒的风暴照样落窗内。

## 证据链

### R9 与 R7 逐行同构（编舞第 5 轮稳定）

mt59 armed → requeue errno=35 → waiter FWRQ errno=110（3s 超时醒）→
UNLOCK_PI ret=0 → owner woken ret=0 → pselect ret=0 errno=0——全链
与 R7 一致，mt60 修复稳定。

### "迟到"而非"卡死"的判别证据

| 判据 | R7（旧解释：卡死） | R9（新解释：迟到） |
|---|---|---|
| calls | 1 | 1 |
| 窗口内 mt19b 打印 | 0 条 | 0 条 |
| 窗口后首个 mt19b | attempt=0 ret=0（成功！） | attempt=0 ret=0（成功！） |
| sched_ok | 0 | 0 |
| 环境 | 负载 ~14.8（LOAD_WAIT override） | 负载 16.02，取证零残留 |

R7 当时判"卡死"的依据是"打印永不出现"——但 R7 输出里第 57 行同样有
`attempt=0 ret=0`，与 R9 相同。两轮的真相都是：syscall 完成，只是
完成时刻在窗口关闭之后。R7 判读勘误：**"卡死"不存在**。

### 时间线（R9）

```
T0        go=1, pselect 进入, 窗口开 (2s)
T0+~ms    consumer 自旋段跑到: 2000-yield 延时 + calls=1
T0+50ms   consumer usleep 睡醒, 进运行队列排队
T0+50ms+? 负载 16/16 核: 排队数秒才上核
T0+2s     pselect 超时返回 (fdset 帧消亡) <- 窗口关
T0+2s+ε   consumer 终于上核: sched 秒回 ret=0, 6 发触发全打空
```

### 负载闸判例（v3 两个闸今天的行为）

- 开火前闸：3×3min 等待后 override 照打（9 分钟白等）
- 轮间闸：R_MISS 后 LOAD_WAIT → 拦掉 R10 重掷（本轮损失一次掷骰）
- 结论：两个闸在"手机日常负载从不 <3"的现实下净收益为负，v4 移除

## 台账更新

| 环 | 状态 |
|---|---|
| 编舞（mt59+mt60） | ✓ 第 5 轮稳定 |
| 窗口（canary EBADF） | ✓ R7 实证已修 |
| consumer 进场 | ✓ calls=1 稳定 |
| **consumer 落窗（负载饿出窗）** | **✗ 当前阻断点 → mt61 修复已交付** |
| 落点（STORE 中 task+0x778） | 未到达（上一步断） |
| 消费（C 轮/AND-gate） | 协议就绪未到 |

## 下一步（卡 6：mt61 首轮 R11）

v4 脚本（仓库 `termux/field_auto.sh`）自动执行：部署 mt61（SHA 机器
校验）→ 取证 → 体检（无负载闸）→ 开火 R11（新增
`PSELECT_WINDOW_SECONDS=20`）→ 机器门槛（R_LANDED → 8 分钟窗口内自动
C1；R_MISS → R12 重掷一次 → 仍 miss 停）→ 回传。

**R11 判读要点**（无论落不落地）：
1. `mt61: pselect window=20s` 行出现 = 新二进制确认
2. mt19b/mt25 打印出现在 `pselect returned` 行**之前** = 风暴落窗内
   （机制修复生效的直接证据）
3. 若落窗后仍 R_MISS → 剩余变量收敛到落点几何本身（pc=task+0x778
   的 R 几何首次在活窗口内被试），按掷骰处理
