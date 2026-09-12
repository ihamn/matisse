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

## 追加：09-13 01:36 轮事故（framework ANR，非内核崩）

### 用户观察
- C 轮期间出现**系统无响应对话框，点“等待”后仍无法关闭**；随后用户软重启恢复。

### 设备侧事实
- boot_id 全程 `f1d8478c…` 未变（uptime 63.2h）→ **没有内核 panic**；pstore 里那份 console-ramoops(262133B) 是 09-10 旧记录
- 内存充裕：MemAvail 4.0GB / SwapFree 7.6GB → 排除 OOM/LMKD
- logcat events 抓到 `am_kill … start timeout`（framework 起服务超时）→ framework 自身卡死
- R 轮：落地成功(task ffffff81600b3780, CapEff 满)，mt87 UNPOISON 正常；
- C 轮：日志停在 prep 的 `found 3 collissions`，**从未进入写阶段**，随后进程消失
- R-child 与 C 轮进程在 ~01:37-01:44 前后同时死亡，ShizukuShellLoader 抛 NPE（会话被清）

### 结论（因果链）
C 轮 prep 的巨量进程/线程克隆 + 页喷，在 63h 老 boot + load 17 下把 framework 拖死 → 系统 ANR 框
→ Shizuku 会话被清 → 由 rish 派生的 exploit 进程被一起杀 → 用户软重启。
**与内核写原语无关（本轮没碰到写）**。

### 修正协议（下轮必须遵守）
1. **硬重启**再开跑：老 boot（>6h）上做 prep 的稳定性显著变差；目标 uptime < 1h、load<25
2. 开火用 **setsid 脱离 rish 会话**（Shizuku 抖动不再连带杀轮次）
3. **R 与 C 之间必须等 R 轮父进程退出**（≥200s），不要背靠背叠两轮 prep（本次即两轮 prep 叠加）
4. 每窗口只打 1 发 C；C miss 就等窗口过期重新 R（不连打）
5. 跑前 am kill-all / 关掉后台大应用（上次有 chrome 多进程在跑）
6. 出现“系统无响应”时：直接软重启恢复，不要在 ANR 状态下继续任何操作
