# Matisse 项目进度看板

> 自动维护，最新更新：2026-08-31

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
