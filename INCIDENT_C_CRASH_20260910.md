# C 轮崩溃事故 + 更安全的手动流程 (2026-09-10 10:4x)

## 事实
- 10:08 R2 首发落地: task=ffffff82ccc19280 (CapEff 满)
- 10:15 C1 发射, 轮询 2 分钟无落地证据 (root_alive 空, child 主观 cred 仍 euid=2000, ksu=0)
- 10:20-10:39 之间我发起 C 重掷 (attempt 2/3/4), 期间整机 panic 重启
  → boot_id 0325ac26 -> f1d8478c, rish(Shizuku) 随重启失效 (需用户手动重启 Shizuku)
- 崩溃后无法取 pstore/dmesg (无 shell 域)

## 崩因最可辩护推断
1. C 是 external 单写: 用 mt49_child_status.txt 里的 task 指针写目标 cred。
   若目标 R-child 已死/task 已回收, 写的就是已释放的 task_struct -> 直接 panic。
   (R-child 的 20min 轮询窗口是独立进程; 若被 pkill/异常退出, 状态文件仍留旧 task 指针)
2. 多轮重叠: 被中断的命令可能连续起轮, 风暴叠加 (项目史: 进程内重试毒化 / 重叠轮崩溃)

## 下轮安全闸门 (人工执行, 不改脚本)
G1 目标存活: C 之前必须确认 R-child 活着 — pgrep -x sleep >= 1 且 status 文件 mtime < 30s;
   否则不击 C, 重做 R (绝不拿旧 task 指针写)
G2 串行化: 两轮之间硬性间隔 >= 200s (round 进程寿命 ~180s), 绝不让两轮重叠
G3 每 R 窗口只打 1 发 C: C miss 不连打; 等该 child 窗口过期, 重新 R 拿新 child 再打 1 发 C
   (连打 C 会让多轮毒链/风暴叠加, 风险累积)

## 顺序 (v7.2 级) 
R (到落地) -> G1 校验 -> C x1 -> 判据(root_alive / ROOT-SEEN euid=0)
   -> 若 C 落地: E5 轮 (串行, 每发间隔 >=200s) 直到 enforce=0
      -> R-child 每秒重试 finit, E5 一翻即自动 insmod (无需再打 C)
   -> 若 C miss: 等窗口过期 -> 重新 R -> 再 1 发 C

## 判据速查
- R 落地: mt49_child_status.txt 含 CapEff=000001ffffffffff
- C 落地: /data/local/tmp/root_alive.txt 有内容(pid..uid=0 euid=0) 或 R round 的 .out 出现 'ROOT-SEEN ... euid=0'
- KSU 装载: /proc/modules 出现 ksu (+ dmesg 'resolver ok')
- 还原: E5R 后 /sys/fs/selinux/enforce = 1
