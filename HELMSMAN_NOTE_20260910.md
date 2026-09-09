# 掌舵审计笔记 2026-09-10 (AI-helmsman session start)

## 会话目标 (用户指令)
掌舵 matisse → KernelSU 可用 + root 长久化: 审计全项目 + 参考 KSU 利用链,
亲自(不依赖脚本)跑通"实测成功的 C 落地全流程", 实现跨重启 root 长久化。

## 时间线重建 (证据: ~/matisse git + 设备 /data/local/tmp + ksu_panic_trace)
- 08-16: P0-A CHILD-ROOT (uid=0,gid=0,零写 cred+0x04) [skill 手册]
- 09-06 18:50 cstrike (mt85 893e0ad7): R LANDED -> C 击后 child
  Uid: 0 0 0 0 / Gid: 0 0 0 0 / CapEff=full  <-- 真·root cred 落地实证
  (root_alive=[] 因 C 后 cred=init_cred -> SID=kernel 致盲, 文件 I/O 被拒)
- 09-08 22:5x hunt (R11/E51/C1): R 落地 CapEff full; E51 child CapEff=0 (E5 未武装?); C1 待查
- 09-09: GKI209 突破 -> kernelsu_gki209_v2.ko (386a0842) 全离线关卡通过; preflight diag ko
- 09-09 23:07-23:19: WILDPTR_INCIDENT(野写/设置重置) -> mt86 UNPOISON + 每 boot 1 发纪律
- 09-10 00:04-02:07: rish argv 静默无效 / rsh1 未定义(R 从未真开火) 修复
- 09-10 02:15 634998f: R env 加 PSELECT_KO=/data/local/tmp/kernelsu_matisse.ko  <-- A1 bug
- 09-10 02:16-02:20 (rsh1 修复后第一次真 R 火): mt49_child_status 02:18 心跳 ->
  panic 02:20 (uptime 98362s boot): rt_mutex_adjust_prio_chain+0x188 NULL deref @0x1
  pstore: x8=0x1 (fd_set 位残值) -> 毒节点 walk 崩 (PANIC_ANALYSIS_20260909.md)
  PANIC_ANALYSIS 判: finit_module 曾成功 (寄存器 x22/x17/x24 落在模块内存区间),
  但该模块到底是 matisse 旧 ko 还是 gki209 v2 存疑 (见 A1)
- 02:20 重启 -> 当前 boot (clean, 无残留 sleep, /proc/modules 无 ksu, Enforcing)

## 审计结论
### A1 [BUG 实锤] ksu_load.sh v3 R 轮 PSELECT_KO 指错模块
- finit_module 只在 R 轮的 fork child 轮询循环执行 (main.c:741-784; C 轮是 external 无 fork)
- R child 预开 fd = R env PSELECT_KO = /data/local/tmp/kernelsu_matisse.ko
  (设备上该文件 = 09-08 23:30 旧 matisse 树 ko 124240B!)
- ksu_load 推送的却是 kernelsu_gki209.ko (v2 152712B) -> R child 会 finit 旧模块
- 修: R env PSELECT_KO = /data/local/tmp/kernelsu_gki209.ko; 并清理陈旧 ko

### A2 [风险] mt86 UNPOISON 压不住 post-round 毒链 walk (02:20 panic)
- unpoison (slide.c:767-784) 在 pselect 返回后执行; panic 可能来自:
  (a) 窗口风暴期间某发触发 walk 到残值词 (words 3-5 pi_tree 或错位词)
  (b) R child 被杀/退出时 futex_exit_release/handle_futex_death 走毒树
  (c) unpoison 自身 LOCK_PI 失败 (target 树顶=毒节点 lock!=真锁)
- 方向 (b01d98c): complete-waiter fdset planting — 10 词全植合法值, 任何 walk 安全
- 深水区已交 fork agent (03aaca7c) 产出带 select.c/rtmutex 源码依据的补丁

### A3 [判据链] 各阶段实测状态
| 阶段 | 实测 | 证据 |
|---|---|---|
| R 落地 (real_cred->init_cred, CapEff full) | 13+ 次 | R11.out 等 |
| C 落地 (cred->root, euid=0) | 有 | cstrike_log 09-06 18:50 Uid 0/0/0/0 |
| E5v3 permissive (enforcing 0 写) | 部分(mt26 时代 Permissive); E51 child CapEff=0 存疑 | E5.out 族 |
| finit_module gki209 v2 | 推断曾发生(panic regs) 但模块归属存疑 (A1) | ksu_panic_trace |
| KSU 管理器转绿 + su | 从未观测 | - |
| 无 panic 跑完全链 | 从未 | - |

### A4 [证据基建] panic 吃掉 R1.out (02:1x 事故)
- ksu_load.sh fire 只 tee tail; 崩溃丢在途文件
- 需: live flight recorder (每 3s 拷 R1.out->持久区) + 重启后 pstore 自动回收

### A5 [外部研究] GhostLock/CVE-2026-43499 交叉印证 (research agent A)
- 真实 CVE; 5.10 全受影响区; 根因 = rt_mutex_start_proxy_lock EDEADLK 回滚时
  remove_waiter 清 current->pi_blocked_on 而非 waiter->task 的 (与本项目 WILDPTR 分析一致)
- OnePlus 变体 JoinChang/ghostlock-oneplus = 本项目同路线 (pselect fd_set 覆写释放栈 waiter,
  PI 链 rb-tree 重平衡写); 5.10 = compact 10-word waiter (word<=7 可行)
- v5.10 rt_mutex_waiter: tree_entry; pi_tree_entry; task*; lock*; [DEBUG_RT_MUTEXES 另+24B];
  int prio; u64 deadline ~= 80B 10 words — 与本项目几何一致 (CONFIG_DEBUG_RT_MUTEXES 影响须实测)

## 修复路线
1. fork agent 补丁 -> complete-waiter planting -> 构建 mt87 (sha/strings 验证)
2. ksu_load v4: A1 修 + flight recorder + pstore autopull + mt87 sha 门
3. 干净 boot: 亲自驾驶 R->E5a(permissive 确认)->C(gki209 finit)->E5R, 实时取证
4. 成功判据: R.out "finit_module OK" + /proc/modules ksu + dmesg "resolver ok" + manager 转绿 + su; 无 panic
5. root 长久化设计 (ksuinit 替代/开机重载/verity 状态核查)
