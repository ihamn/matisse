# R5 预判表（评审侧预备 · 开火前预注册）2026-08-16

> 作用：对面按 GRUNT_CARD_2 推回 R5 原文后，本表让判读零延迟。
> 预注册 = 数据未到先写死预测，防事后拟合。对面不许用本表自行判断，照旧只推原文。

## A. mt60 四条新日志行的预期值

| 行 | 预期（mt60 理论成立时） | 反例 → 结论 |
|---|---|---|
| `mt60: pre-requeue words` | `f_wait=1 target=? chain=?`（R4 已证 requeue 时 f_wait 必为 1，errno=35 过了 cmpval 检查） | f_wait=0 → FACT 4 重开：errno=35 另有来源，cmpval 理论被证伪 |
| `mt60: waiter FWRQ ret=... errno=110` | 3s 超时醒（ETIMEDOUT=110），随后 stack_copy/consume 链恢复 | ret=0（拿锁）→ EDEADLK 形态未发生，走的是 requeue 成功形 | 
| `mt60: waiter FWRQ errno=11` | EAGAIN=未阻塞 → R1 真胜路径候选坐实（FACT 4 领跑解释） | — |
| `mt60: owner chain LOCK_PI ret/errno` | 阻塞中被 requeue 撞环（不可见直到退出） | ret=0 → owner 没挂上，armed 握手假阳性 |
| `mt60: STALL flags`（若出现） | 旗标快照定位断链点：`consume_go=0` = waiter 没醒；`route_done=0` = 醒了但 pselect 没回 | — |

## B. rc 判读（mt60 语义）

| rc | 含义 | 评审动作 |
|---|---|---|
| 0 | 全链走完 180s 正常退出 | 看 trigger ret 与 CapEff 行定胜负 |
| 3 | watchdog 自弃（mt60 首次真实 rc=3） | 按 STALL flags 定位断链，预算不耗 |
| 124 | harness 超时真挂 | 依惯例调查，不重跑 |
| 255 | 旧 pr_error 路径泄漏（不该再出现） | 二进制混入旧版 → 停，查部署哈希 |

## C. 胜负判定链（不变）

`requeue fired ret=0 errno=35` → waiter 3s 醒 → `stack_copy` → `consume_go` → trigger →
`mt22: wrote=N`（N>0 = 写落地）→ `getenforce`/CapEff 定格。

## D. ANR 归因悬案（等 step2 证据）

- trace 若指向 `am kill-all` 后的 binder 洪峰 → 环境理论成立，跑法不变。
- trace 若指向我们进程退出引发的 OWNERDIED 唤醒链 → 需在下一版给 owner 加干净退出口。
