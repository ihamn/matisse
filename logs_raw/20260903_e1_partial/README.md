# E1 PC_OFF gradient partial (2026-09-03)

## 结果
| round | PC_OFF | stage | 风暴 | 观测 |
|---|---|---|---|---|
| off770 | 0x770 | R | 6 发 full | R 写 real_cred 落地：CapEff=000001ffffffffff |
| off788 | 0x788 | C | 6 发 full | **comm 被污染**：/proc/<child>/comm 变成垃圾字节 |
| off778 | 0x778 | C | 未到触发 | 日志停在 prepare，脚本/设备中断 |

## 判读
- off788 污染 comm 说明**主树 erase 的 STORE 对 pc>=0x778 的几何确实会执行**。
- 这支持 H3（0x780 cred 写入被事后中和/回滚），而不是 H2（erase 根本没执行）。
- 但 off778 未完成，尚未直接看到 0x780 写后状态；E4a 也失败，仍需更多证据。

## 系统异常
- 实验期间/之后用户报告“短暂连续两次重启但应用未清除”，疑似 system_server/zygote 软重启。
- 当前 boot_id=0ef4fdc9，uptime 长，loadavg 一度 186/1166/767，内存仅 266M free。
- **所有现场实验立即停止**，等待系统恢复后再继续。
