# Matisse 项目进度看板

> 自动维护，最新更新：2026-09-01

## 当前主目标
CVE-2026-43499 临时 root → KernelSU。

## 当前阻塞
C 阶段（写 task+0x780 cred）0/6 未落地；R 阶段（写 task+0x778 real_cred）7/7 落地。

## 待跑隔离实验（mt70）
| 实验 | 脚本 | 目的 | 成功判据 |
|---|---|---|---|
| R 外部模式 | `run_holder.sh` + `run_Rext_test.sh` | 隔离 fork vs external 模式 | status CapEff=000001ffffffffff |
| C fork 模式 | `run_Cfork_test.sh` | 隔离 pc 0x778 本身是否可写 | status euid=0 |
| 几何互换 B | `run_geomB_test.sh` | R fork 几何写 0x780 | status euid=0 |

## 现场前置条件
- Shizuku 运行中
- 屏幕常亮 + 插电
- 部署 mt70：`bash termux/deploy_mt70.sh`

## 最近交付
- mt69：`PSELECT_PTR_PC_OFF`
- mt70：`PSELECT_PTR_PC_OFF` + `PSELECT_HOLDER`
- 插件：`@dhicoc/dsh-reverse-skill`、`@linxin666/dsh-client-ui-task-board`

## ⚠️ 2026-09-01 崩溃记录
- 昨晚自动跑 R-external 隔离实验时，Rext4（60s 窗口、PSELECT_ENTER_DELAY_USEC=0）导致手机重启。
- 新 boot：`bf1c84d3-2dfa-4a96-8098-e8f89e718a33`
- `/data/local/tmp/Rext4.out` 为全 NUL（panic 前未 flush 或页缓存丢失），无法从该文件定位崩溃点。
- Rext3 记录完整：consumer 风暴被饿出 20s 窗口（`pselect returned t=20012ms` 后 `mt19b t=20013ms`），0 发。
- Shizuku 重启后未运行，当前停止一切现场实验。
- 教训：不要在 consumer 已连续饿出窗口的环境下加长窗口硬试；应先等负载/调度恢复，或先跑只读取证确认无残留。

## ⚠️ 2026-09-01 追加：R-fork 健康检查也饿窗
- 恢复 Shizuku 后跑了一次标准 R fork（mt70，20s 窗口），同样 consumer 被饿出窗口：0 发。
- 说明当前环境不适合跑触发实验，不是外部模式独有。
- Shizuku 随后又变为未运行，现场实验再次停止。
