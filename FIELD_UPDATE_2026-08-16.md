# 现场更新（简短）— getfield 修复 + pstore 栈待裁定 (2026-08-16)

1. **getfield bug 已修并推**（fa852c1）：STAGE-R 外部模式 rc=127 根因 = awk 取值把
   整行打出（task=XXXX uid=2000...）→ PSELECT_TASK env 非法。已改 grep -o 精确提取。
2. **pstore 栈**（4fc7674）：崩在 rt_mutex_adjust_prio_chain+sched_setattr，栈上有
   我们的写值。**请裁定是否影响 mt49（RETRY=1 已免疫同进程二触？还是 prio_chain
   是独立路径需要改？）** —— 这是等您期间唯一的未决点。
3. **设备 boot 已疲劳**（MemFree 189MB, 应用秒退）→ 我们重启换 boot。
4. 重启后我们**先跑 R0 判活**（所有版本必做，不浪费）；若您已回复则按您的裁定跑，
   未回复则先跑当前 mt49（getfield 已修 + RETRY=1 结构性免疫，风险可控）。
5. 若您裁定 mt49 需改，发新补丁即可，我们会在 R0 后接上。

—— matisse 现场
