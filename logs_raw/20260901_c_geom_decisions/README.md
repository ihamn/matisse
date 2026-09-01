# 2026-09-01 C 几何决定性实验记录

## 结果
| 实验 | 模式 | pc | 风暴 | 写落? | 证据 |
|---|---|---|---|---|---|
| Rfork2 | fork, stage=R 默认 | 0x770 | 6 发，t=17.5s 进窗 | ✅ real_cred 落地 | status CapEff=000001ffffffffff |
| C1_auto | external, stage=C | 0x778 | 6 发，t=51ms 进窗 | ❌ cred 未落 | status euid=2000 |
| Cfork_auto | fork, stage=C | 0x778 | 6 发，t=2s 进窗 | ❌ cred 未落 | status euid=2000 |
| GeomB_auto | fork, stage=R + PC_OFF=0x778 | 0x778 | 0 发（饿窗） | 未判定 | pselect 20s 后才 mt19b |

## 结论
- C 0/N 不是外部模式问题：C fork 模式同样全风暴仍不写。
- C 0/N 不是时序问题：C1_auto 在 51ms 即全风暴仍未写。
- 候选根因收敛为 **pc=task+0x778 / 写 task+0x780 cred 的几何/目标字段本身不落地**。
- GeomB 本次饿窗，需以后补一次“R fork + PC_OFF=0x778 + 全风暴”来交叉确认；但 C fork 已等价验证。

## 设备状态
- 未崩溃，boot 仍为 bf1c84d3。
- 后续停止继续烧机；Shizuku 已释放。
