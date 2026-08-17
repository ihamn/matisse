# R7/R8 判读（评审侧）2026-08-17

## 总判决

1. **canary 理论实证命中**：R7 无 canary 行、`pselect ret=0 errno=0`（窗口
   干净 held 满 2s）、`calls=1`（consumer 进场）。R6 判读的修复生效。
2. **新阻断点定位（第三环）**：consumer 线程在第一次
   `SYS_sched_setattr(waiter_tid)` 内核调用里**卡死不返回**——窗口内零打印
   + `last_sched_ret=-1/errno=0` 初值未动 + `sched_ok=0`，与 A1_2 的
   `last_sched_ret=0`（秒回）构成完美判别器。erase 触发链断在最后一环。
3. R8 = 污染轮（B 站 10:08 前台 + 卡死线程负载 + 29 行即被外层 timeout
   击杀），**从证据链剔除**。
4. 副产物两个 bug 实锤：陈旧状态文件门槛洞（R8 删文件被闪断吞掉，
   读到 R7 旧文件）、rsh 重试提示泄进收集文件。

## 证据链

### canary 修复生效（R6 判读的判据逐项兑现）

| 判据 | 预测 | R7 实测 |
|---|---|---|
| canary planted 行 | 消失 | ✓ 无 |
| pselect 返回 | ret≥0 errno=0 | ✓ ret=0 errno=0 |
| consumer | calls≥1 | ✓ calls=1 |

窗口 = `PSELECT_TIMEOUT_SEC=2`（common.h:132），满 2s 超时干净返回。

### consumer 卡死的四重证据（slide.c:318-441 逐行推演）

1. `calls=1`：consumer 通过了自旋/lost 检查/50ms 延时，进入 sched 段
   （line 323-326 计数）。
2. **零 mt19b 打印**：打印在调用返回之后（line 338→340）。waiter_tid 在
   线程入口即存（line 477，远早于窗口），a=0 必然带合法 tid 进调用——
   唯一解释：调用未返回。
3. `last_sched_ret=-1 last_sched_errno=0`：line 327-328 初值，a 循环一次
   未完成（完成必写 best_ret，line 348-351）。
4. `sched_ok=0`：sched_ok 的两处写入（line 432 burst 完成 / line 433-436
   sched 成功 +1）都未到达。

### sched_ok 语义破解（勘误 R6 判读）

`sched_ok` ≠ "sched 成功"，= `trig_hits>0`（trigger 命中）**或** sched
ret=0 的 +1。A1_2 的 `sched_ok=1` 来自后者（其 6 发 trigger 全 errno=110
未命中）。真正的判别器是 `last_sched_ret`：**A1_2=0（sched 秒回），
R7=-1（sched 卡死）**。A 系列与 R 系列的全部剩余差异收敛到这一点。

### R7 窗口内 trigger 形态变化（次要观察）

R5/R6 窗口后 trigger0 ret=0（EBADF 秒退、栈帧残留）→ R7 全部 errno=110
（ETIMEDOUT=真阻塞超时，f_pi_target 被 owner 持有的真态）。与 A1_2 形态
一致——进一步佐证 R7 已回到真窗口流。

### B 站 10:08 卡顿 = 负载级，非系统楔死

dropbox 仅 2 条 ANR（微信广播、onStopJob），**无 B 站、无 system_server**。
时间线：R7 窗口 ≈10:05:35-37（2s）；R8 开火 ≈10:06:40、克隆风暴
10:07-10:08 → B 站 10:08 前台卡顿 = R8 克隆负载（272+204+33+34 子进程）
+ 可能的 R7 卡死线程占核叠加。boot 全程未变、Enforcing、R8 仍能跑 = 系统层健康。

### 陈旧文件门槛洞（R8 证据剔除的补充理由）

`mt49_status_final.txt` 内容 task=ffffff811f582500 = **R7 的 task**。
R8 开火前的 `rm` 被 Shizuku 闪断吞掉（同一闪断把重试提示泄进了
C1_termux_raw.out——那 2 行不是 C 轮输出，C 轮从未开打，门槛纪律正确）。
R8 门槛读到 R7 旧文件判 R_MISS——碰巧正确，纯运气。v3 已堵。

## 台账更新

| 环 | 状态 |
|---|---|
| 编舞（mt59+mt60） | ✓ 已解决（连续第 4 轮稳定） |
| 窗口（canary EBADF） | ✓ 已解决（R7 实证） |
| consumer 进场 | ✓ 已解决（calls=1） |
| **sched 触发（内核卡死）** | **✗ 当前阻断点** |
| 落点（STORE 中 task+0x778） | 未到达（上一步断） |
| 消费（C 轮/AND-gate） | 协议就绪未到 |

## 下一步（卡 5：取证优先，重启后单轮验证）

1. **取证（零开火）**：若 R7 的 preload 残留（卡死线程会让进程僵在 D 态），
   读 `/proc/<pid>/task/*/stat`（state）+ `wchan`（内核函数名，shell 可读）
   ——若拿到 consumer 卡死的内核符号，机制定罪完成。
2. **重启手机**（清掉卡死线程/B 站/负载；boot_id 会变，属预期）。
3. v3 脚本单轮 R9（配方不变）验证卡死签名是否确定性复现：
   `calls=1`+零打印+`last_sched_ret=-1` 三件套再现 → 确定性内核卡死 →
   mt61 改触发路径（如 owner-tid 优先 / SCHED_IDLE / sched_getattr 探测）；
   若 R9 sched 秒回（last_sched_ret=0）→ 随机竞态，连跑收集统计。
