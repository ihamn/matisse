# 方向1 结论: 5.10 写 cred 指针 → init_cred 必崩 (2026-08-15 18:42)

## 三次测试规律
| 版本 | 写目标 | 结果 |
|---|---|---|
| mt32 | 活跃任务 task+0x780 → init_cred | attempt1 崩 |
| mt33 (1st) | 阻塞子进程 → init_cred | 跑到 attempt1 不崩 (Shizuku 杀) |
| mt33 (2nd) | 阻塞子进程 → init_cred | 崩 (写触发后) |
| mt34 | 子进程永不退出+不杀 | 崩 (round1 早期) |

## 结论 (正本清源)
**5.10 上写 task->cred 指针 = init_cred 这条路本身必崩** (内核访问新 cred 时 panic),
不管写活跃任务还是阻塞子进程。不是代码 bug, 是 5.10 的 cred/RCU 访问路径与 6.12 不同。

## 验证了 fresh-eyes 的版本差异警告
ghostlock 的 W2 经验 (6.12) 不能直接移植到 5.10。TASK_CRED_OFF 不同 (6.12=0x900, 5.10=0x780),
访问路径也不同。

## 下一步: 方向2 - 不写 cred 指针, 改写当前真实 cred 的内容
- 思路: 写 task->cred 指向的 cred 结构体内部的 uid/gid/caps 字段 (不是改指针)
- 优点: cred 指针不变, 内核访问路径不变, 可能不崩
- 难点: 需要任意值写 (Case-2 写 tree_left=cred 内部字段地址)
- 已确认: Case-2 写能触发 (mt28o/mt31), PSELECT_W 链已修好 (env 优先)
- 需要: cred 结构体内部字段偏移 (CRED_UID_OFF=0x8 已有), 写值 = 0

