# CHECKPOINT — mt79/E5v3r2 + 09-06 凌晨现场轮复盘 (R✓ / E5v3安全拦截 / C中断+软重启)

## 现场时间线 (2026-09-06 01:09-01:20, boot=ab549482 全程未变 → 内核始终存活)
1. 01:09 R 轮(CPU6, mt78 build): perf task=0xffffff80426e4a00 (198/256票),
   6 发风暴全正常 → **CapEff=000001ffffffffff 落地 ✅** (连续第 8 次 R 成功)
2. 01:11 E5v3: fake_lock=0xffffff81062c04d0 (页基址+0x4d0, 尾字节 d0) →
   mt78 运行时校验器 ABORT ✅ 零事故 (设计目标达成)
3. 01:14-01:17 C 轮 (无 E5, 直打 R-child, stage C): 触发链完整
   (EDEADLK 35 → FWRQ 110 → UNLOCK_PI 0 → pselect 窗口上膛 6 发)
4. ~01:18 **软重启** (framework 级; boot_id/uptime 连续, 非内核 panic)
   → C 进程被连带杀死, 窗口内是否命中【无法判定】; logcat 滚动/dropbox
   拒读, 用户态死因取证到头 (system_server 死亡, 与历史自发软重启同型;
   load 16.7 + 每轮克隆 500+ 进程的内存压力是重要诱因)

## 根因修正: mt79 (E5v3r2)
- fake_lock = payload_base+0x1350, payload_base = page_base-0xe80 → 非页对齐!
- 修正: E5 child 用 ★page_base★ (真页对齐): SPRAY=page_base (byte0=00 →
  enforcing=0), SPRAY1=page_base+1 (byte0=01 → enforcing=1)
- byte2=0x2c ≠0 (initialized 保留); 校验器 (byte0∈{0,1}, byte2≠0) 不变
- STORE(b) 污染页首 0xe80 布局零区 — put64 布局从不写该区, 牺牲安全
- preload.so SHA256: 75728bb8b2e31c4cb91165859016d0866635b3ba8a888cf00e96ad5333c9e85e
  已部署 /data/local/tmp/preload.so + 工作区 preload_mt79.so

## 现场纪律更新 (软重启教训)
- ★load gate 不再放宽: >15 一律不跑★ (01:17 轮 load 16.7 是本项目首次
  顶着超载开火, 结果就是软重启 — 相关性已记录)
- 每轮 storm 克隆 500+ 进程; 连续轮之间至少隔 3-5 分钟让内存回收
- 软重启 ≠ 内核崩溃 (boot_id 判别): uptime 连续 = framework 重启, pstore
  不会有新 panic, 别浪费轮次找

## 下一步
1. E5v3r2 (SPRAY 默认) 现场一轮 — 判定 v1 黑屏根因 (H-A vs initialized=0)
2. 无 E5 的 C 轮重试 (mt73 sethostname 信标 + R 先行) — 本次 C 因软重启
   中断, 内核全程无恙说明双 erase 也不 panic, 可在低负载下重试
3. C 铁证 (hostname=glroot / Uid:0) 拿到即 root 到手; E5 只剩 KSU 加载用途

## 补充 (08:44): E5v3r2 两轮 fork 模式复盘 + 软重启 #2
- 第 2 轮 (08:29, load 13.6 达标, 屏幕常亮): rc=124 跑满, out 冻结在
  "found 3 collisisons" → 卡死在 KernelSnitch 之后的 mm_struct 暴力扫描
  (8 线程 VA 扫描, 内存密集) → D 状态堆积 load 2631 → system_server 饿死
  → framework 软重启 #2 (boot_id ab549482 仍连续, 内核零伤, enforce 未动)
- 两轮对照: 第 1 轮扫描通过但息屏毁窗口; 第 2 轮屏幕正常但扫描 thrash。
  共同点: fork 模式 E5 轮的扫描阶段对内存压力极敏感 (9h uptime + swap
  3GB + bilibili 1.2GB RES)。
- ★对策★: ① 回归 mt77 已验证的 external 序列 (R 先行 → E5v3 external
  PSELECT_TASK=<R-child> → C → E5R); ② 跑前关重应用清内存; ③ R 轮本身
  8/8 稳定, 即使 E5 失败仍有 R-child 可打 C 信标; ④ 轮间冷却 3-5 分钟。
- E5v3r2 几何本身已验证正确 (第 1 轮 mt79 打印: enforcing=00
  initialized@+2=36, 校验器放行, 触发链全绿) — 只欠一个稳定的执行环境。

## 理论分析定案 (10:58): E5 三连卡死 = kill_child waitpid 阻塞, 非几何非回归

### 证据链
1. git 考古: 27d06cc(mt77 构建) 之后引擎源码零改动 → mt78/79 构建 ≈ mt77 构建,
   kernelsnitch.h 同为 exploit/src 的 7月16日版(mt61 配方同一来源) → 排除构建回归
2. 卡点定位: 三次卡死输出都停在 "found 3 collisisons"(leak child 的最后一句,
   ks->state 已置 COLLISIONS_FOUND, find_collisions 已完成) — 父进程的
   "spray children killed" 再未出现 → 父进程卡在 post/spray kill 循环
3. kill_child (util.c:487): kill(SIGKILL) + **阻塞 waitpid**。34 个 spray
   子进程 + 543 克隆峰值 + 内存压力 → SIGKILL 的子进程困在 D 状态
   (futex/memfd 不可中断内核路径) 不死 → waitpid 无限等
4. 三种 rc 形态全部解释: rc=124(08:29, sleep180/timeout250 阻塞到超时);
   rc=0(10:47, 构造器在后台线程, sleep130 主线程到点 exit(0) 把阻塞线程
   一起带走); rc=255(08:11, 校验器 ABORT 预期路径)
5. 源码自认: util.c:862 注释 "ks collision finding is flaky/slow"
6. mt77 为何能过: E5v2 当晚通过扫描 → D 状态排空时间是概率性的, 与系统
   内存状态强相关; 今日 12h uptime + swap 压力下恶化

### 修复方向 (择一或组合)
A. 【零代码】给足时间: E5 轮 sleep 350/timeout 400, 赌 D 状态最终排空
B. 【代码】kill_child 改非阻塞: 先全部 kill, 再 WNOHANG 轮询收尸 + 有界
   等待(如 30s), 超时放弃 reap 继续推进(waitpid 只为防僵尸, 不阻塞主流程)
C. 【代码】减少克隆规模 (272+204+33+34 → 砍半), 降低 D 状态堆积概率

### 判别实验
A 跑一轮: 若 400s 内完成 → 阻塞有限, 方案 A 即可; 仍冻结 → 阻塞无限,
必须上方案 B (WNOHANG 补丁)。

## ★ 11:38 定案: 第二触发轮踩爆 R 毒化 PI 链 — kernel panic 实锤 (pstore)

### panic 现场 (11:28:46, boot b07e72d1, uptime 3046s)
- bootreason=kernel_panic (本次非 longkey)
- pc: rt_mutex_adjust_prio_chain+0x9fc/0x1948, Oops 96000004
- 坏指针: x19=0x0008000000000000 (被遍历的 waiter 节点=垃圾), x8=x19+0x40
- x1/x27 = 0xffffff811a0a84d0/8 = 喷页 fake_lock (base+0x4d0 特征吻合)
- x25/x5 = 0xffffff8116ba64xx (同喷页区) — PI 链正在穿我们的假锁区
- 触发者 T628728 = 探针轮(E5 external, PSELECT_TASK=<11:15 链的 R child>)

### 机制
R 轮 erase 后, R-child 的 rtmutex waiter/PI 树里留着我们的假节点(部分词
已写/部分垃圾)。对该 child 的**任何第二次 futex/rtmutex 触发**(C/E5
external)都会让内核 walk 这棵毒树 → prio_chain 解引用垃圾 → panic。
0x0008000000000000 = 半成品 waiter 词(部分 fd_set 覆写残留)。

### 今日全部崩溃归因(重排)
| 时间 | 轮次 | 结果 |
|---|---|---|
| 01:18 | C external on R-child (R 01:10 落地) | framework 死 (软重启#1) |
| 08:44 | 链 C 阶段 on R-child (R 08:10 落地) | framework 死 (软重启#2) |
| 11:29 | E5 probe external on R-child (R 11:18 落地) | **kernel panic** |
→ 三次全是"对已毒化 child 的二次触发"; 与 E5 写本身无关(从未发射)。

### 剩余独立谜团
- KernelSnitch 扫描冻结 (fork/standalone 4/4): kill_child 补丁无效,
  父线程在 pre/post kill 区间静默失联, 机制未明 — 需活体 wchan 解剖

### 战略结论
1. §6.4 的 R→E5→C→E5R 同 child 背靠背链在本内核上**结构性不安全**, 废止
2. R 几何单发 10/11 — 引擎对单轮写完全可靠
3. 下一步三选: (a) C 改 fork 模式(需先解扫描冻结) (b) 研究 R 毒化树的
   排毒/复用策略 (c) 每 boot 只打一轮 R+C 一次性组合(接受毒化风险)
