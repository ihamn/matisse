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

## \u4fee\u6b63 (v4.2, 03:35) - C \u843d\u5730\u8bc1\u636e\u72b6\u6001\u91cd\u5ba1
- 20260907_ROOT_EVIDENCE \u5df2\u88ab\u5bf9\u9762\u590d\u6838\u64a4\u56de: /proc/PID/status Uid \u56db\u5143\u7ec4
  \u53ea\u8bfb task+0x778 (real_cred, \u6307\u4ee4\u7ea7\u6838\u9a8c) \u2192 \u65e9\u5148\u5f15\u7528\u7684 "cstrike Uid 0/0/0/0"
  = R \u843d\u5730 (real_cred=init_cred) \u7684\u53e6\u4e00\u79cd\u5f62\u6001, \u4e0d\u662f C \u843d\u5730
- \u4e3b\u89c2 cred \u7684 C \u843d\u5730 (\u7528\u6237\u6001 getresuid euid==0) \u4ece\u672a\u88ab\u5e72\u51c0\u89c2\u6d4b
  (mt49_child_status root_seen=0 \u4e00\u76f4) \u2192 finit_module \u4e5f\u4ece\u672a\u786e\u8ba4\u6267\u884c
- P0-A (08-16) \u662f\u552f\u4e00\u7684 cred-\u5185\u5bb9\u5199\u5165\u5b9e\u8bc1 (uid@+4 \u96f6\u5199, \u5b50\u8fdb\u7a0b
  getresuid uid=0) - \u4f46\u8be5\u8def\u7ebf euid/suid \u672a\u96f6, \u4e14\u4e0e PTR \u6307\u9488\u6362\u4e0d\u540c\u673a\u5236
- \u2460 \u610f\u5473: \u8fd0\u884c\u9884\u671f = R \u843d\u5730\u9ad8\u6982\u7387, C/E5/finit \u5747\u672a\u8bc1\u5b9e,
  \u4e14 ROOT-SEEN/finit \u8bc1\u636e\u5728 R1.out (R child stdout) \u2192 v4.2 C \u540e\u518d\u56de\u62c9 R1.out
- \u2461 mt87 \u4e4b\u524d\u7684 panic \u4e0d\u80fd\u8bc1\u660e "finit \u5df2\u6210\u529f"; \u6a21\u5757\u5185\u5b58\u533a\u5730\u5740
  0xffffffd1... \u4e5f\u53ef\u80fd\u662f exploit \u81ea\u5df1\u7684 vmalloc \u55b7\u9875


## ★★★ 重大支线发现 (2026-09-10 03:45) - mqsas 免解BL root (替代内核 exploit 路线) ★★★
参考: mrdong916/mi_nobl_root (Xiaomi15/HyperOS3/6.6 LKM 运行时加载 KSU):
  service call miui.mqsas.IMQSNative 21 i32 1 s16 'sh' i32 1 s16 '<脚本>' s16 '<输出>' i32 <超时>
  = 以 root (hypsys_ssi_default 域) 执行任意脚本 -> insmod kernelsu.ko
  (https://github.com/mrdong916/mi_nobl_root)
本机实证 (03:45):
  - service list: #186 miui.mqsas.IMQSNative [] 存在; #187 MQSService;
    #338/339 xiaomi.system.hypsys.common.IHypSysSsi(/Intl)
  - 从 Termux app 域 (u0_a474, untrusted_app) service call -> "does not exist"
    (getService find 被 SELinux 拒, 预期) -> 必须从 shell 域 (rish) 试
  - ⭐ 下轮 rish 恢复后第一件事: shell 域跑 mqsas call 21 试 root
    若成: id=root + hypsys 域 -> 试 (a) setenforce 0 (b) insmod kernelsu_gki209_v2.ko
    -> 整条 CVE-2026-43499 内核 exploit 链可被绕过 (每 boot 秒级 root)
  - 未知: HyperOS 2.0.6.0 (Android14/5.10) 上该接口/事务21是否仍有效;
    hypsys 域在 Enforcing 下 insmod 是否被 module_load AVC 拒 (mi_nobl_root 仅 permissive 测过)
