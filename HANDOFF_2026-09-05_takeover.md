# 交接文档（分析侧）— matisse CVE-2026-43499 / GhostLock 全量接管

> 写给下一个 AI 会话：你将**同时接管静态分析与实验设计**（对端「对面」是现场
> Termux 执行者）。本文与现场侧 `HANDOFF_2026-09-05_mt77.md` 互补：那份讲现场
> 纪律与操作，本文讲**知识库、未解之谜、下一步打法**。先读两份 HANDOFF，再按
> §7 优先级行动。写作时间 2026-09-05，仓库 HEAD `642fa1d`。

---

## 1. 项目一句话与总状态

CVE-2026-43499（rtmutex UAF，GhostLock 变体）在 Redmi K50 Pro（matisse，
HyperOS 2.0.6.0.ULKCNXM，kernel 5.10.209-android12-9，**KASLR=0**）上打
cred 覆写 → root。终极目标 KSU，**但用户明确：root 成功后不得用 root 权限对
手机做任何操作；是否继续 insmod/KSU 需用户另行授权**。

| 能力 | 状态 | 证据 |
|---|---|---|
| 内核页定位/喷页/perf task 识别 | ✅ 稳定 | 每轮日志 mt28c/mt39/mt40 |
| R 写（real_cred@0x778=init_cred） | ✅ 7/7 + mt77 落地 | `R_mt77_landed.out` |
| C 写（cred@0x780=init_cred） | ⚠️ 极可能落地但**不可见**（致盲） | off788 对照 + 静态排除 |
| E5 写（selinux_state 零写/置值） | ✅ 机制落地（enforce=0 ×2） | `logs_raw/20260905_e5/` |
| E5 之后系统存活 | ❌ 3/3 重启/黑屏挂死 | §5 三个假说 |
| consumer 防饿（mt77 CPU6） | ✅ 实证 | `R_mt77_landed.out` |
| mt73 无文件信标（sethostname） | ⏸ 未在全风暴下验证 | 代码已交付 |
| KSU（finit_module + vermagic bypass） | ⏸ 已写好，未到触发条件 | mt50/mt52 |

---

## 2. 工作模式与环境

- **沙盒会不定期重置**：`/data/user/work/matisse` 可能消失，重建：
  `git clone https://ihamn:c95ffcbb04d320ab39e2de6d950a023a@gitee.com/ihamn/matisse.git`
- **gitee 频繁限流**（`expected flush after ref listing`）：等 60-120s 重试即可，
  clone/push 都会遇到。**重要产物先本地写好再一次性 push**。
- 分析依赖：`pip install pyelftools capstone --break-system-packages`（重置后要
  重装）。内核符号镜像：`ref/kernel_with_symbols.elf`。
- 协作流：我方（分析侧）出结论+补丁 → push gitee → 对面（现场）构建执行 →
  推 logs_raw + README 回来 → 我方分析。**对面构建在 Termux**（clang 21.1.8,
  API 35），见 `bin/mt76/BUILD_INFO.txt` 格式。
- 用户语言中文；输出保持精简（用户多次强调余额有限，不要干多余的活）。

## 3. 已验证事实库（全部指令级/实证，勿重做）

### 3.1 task_struct 偏移（matisse 5.10.209）
| 偏移 | 字段 | 备注 |
|---|---|---|
| +0x770 | ptracer_cred | R 几何 PC 落点 |
| +0x778 | real_cred | R 写目标（STORE(a)） |
| +0x780 | cred | C 写目标 |
| +0x788 | 未知 8 字节 | 初值 0，全内核无访问者（C 判别字，恒 ≠ node） |
| +0x790 | comm | off788 实验污染的就是它（16 字节） |

### 3.2 rb_erase 写原语（@0xffffffc008a71228，CASE_A）
- `pc=word0`，`parent=pc&~3`；判别字 `*(parent+0x10)==node`？ne → **STORE(a)
  `*(parent+8)=child(word1)` 必然执行**（判别字是随机内核数据）。
- `child==0` → STORE(b) 被 `cbz x8`(@0x29c) 守卫跳过；`child≠0` → 永不 rebalance。
- child==0 时 rebalance 条件：`pc bit0==1`（@0x360 `sbfx`）→ **RB_RED=0 /
  RB_BLACK=1**（fops.c 老注释"RED 已置位"是反的！TREE_PC 必须 `&~3`，`|1`
  会进 `__rb_erase_color` 旋转 = 致命）。
- **3.2 写原语编码**：`TREE_PC=word0, TREE_RIGHT=word1, TREE_LEFT=word2`；
  PI 词 word3/4/5 走 pi_tree 路径（保持 0 = root 无害）。
- **★基本约束（2026-09-05 交接前最后推导，已代码核实）**：两条几何里每个
  指针词都会被解引用——主树 STORE(a) 的载荷=child(word1)，而 child≠0 时
  STORE(b) 又写 `*(child+0)=pc`；pi_tree 同理（word3 被 `*(word3+8)` 解引用）。
  **因此写值只有两种合法形态：0（单 store）或「可写牺牲指针」（双 store，
  附带污染该指针+0 处 8 字节）**。小常数（0x10000 等）一律 panic。R 几何合法
  正因 child=init_cred 别名是有效可写指针（STORE(b) 污染 init_cred+0 的
  usage/uid——usage 变巨大防释放、uid 变垃圾但 euid@+0x14/caps@+0x20 完好，
  无害）。
- **E5 几何**：PC=`(selinux_alias-8)&~3`，RIGHT=child=**写值**，LEFT=0。
  v1 值=0 → child=0 → 单 store（干净，已实证落地）。

### 3.3 SELinux 布局（Android 重排，非 upstream）
| 项 | 值 | 出处 |
|---|---|---|
| selinux_state | 0xffffffc00aa41b98（内核 VA） | readelf |
| enforcing | **state+0** | `avc_denied+0x1c ldarb [state]; tbz #0` |
| initialized | **state+2** | `security_compute_av` 入口 `ldarb [state+2]` |
| avc 指针 | state+0x48 | 同上函数 |
| 别名 PC | 0xffffff8002a41b90（phys alias，KASLR=0） | E5 现场日志 |
| 引用者 | 159 个函数全为 SELinux 自身机制，**无 OEM 看门狗** | `find_state_xrefs.py` |
| 清零窗 +0..+7 | 无指针（xref 只物化 +0/+2/+7） | 同上 |

### 3.4 检测通道语义（C 悖论的解）
- R 后子进程：CapEff 显示满（/proc CapEff 读 **real_cred**）、getresuid()==2000
  （cred 未动）→ mt47 日志 `uid=2000 CapEff=full`。
- C 后（cred=init_cred）：getresuid()==0，但 **SELinux SID 变 kernel → enforcing
  下子进程自身文件 I/O 全被拒**（status/心跳/日志全哑）→ 表现为假 0/N。
  off788 对照（只污染 comm@0x790）心跳正常 30s+ —— 证明 C 几何的 erase 在执行，
  「失败」纯粹是检测被致盲。
- **/proc/<child>/status 打开时做 ptrace_may_access 检查**：C 后子进程 euid=0，
  uid2000 父进程**新开**它的 status 会被拒；但**预先打开的 fd 可继续读**——
  这是无 E5 的取证通道（§6.3）。
- capable() 用主观 cred（task->cred）→ R-only 子进程**不能** sethostname；
  C 落地后才能（mt73 信标的原理）。

### 3.5 关键常量
`init_cred=0xffffff80027b0ae0`，`INIT_TASK=0xffffff800279bec0`，
`CAP_FULL=0x000001ffffffffff`。物理别名宏 `P0_DATA_ALIAS_CONST`（common.h）。

## 4. 故事线（时间轴压缩版）

1. **mt47/48**：R 几何 7/7 落地，C 几何 0/N → 「C 悖论」。
2. **9/1**：指令级反汇编确认 C 应写（0x788 判别字恒 ne）→ 结构性矛盾；E4
   pi_tree 备用几何写入 main.c。
3. **9/3 E1 梯度**：off788 污染 comm 成功 → erase 确在执行；off778 全风暴
   「无效」→ 差 8 字节定界中和机制只针对 cred 槽。
4. **9/4 解悖**：静态证明全内核无 cred 回滚路径 → **致盲假说**（kernel SID
   + enforcing 拒子进程 I/O）；mt73 无文件信标交付。
5. **9/4-05 E5**：v1 全零写 → enforce=0 ×2 落地，但 50-80s 后黑屏挂死 ×2
   （≈watchdog 周期）；内核侧三假说全静态排除（无看门狗/无指针/initialized=0
   全放行）→ 杀手在用户态。
6. **9/05 mt76/77**：E5v2（保 initialized=1，值 0x10000）+ E5R（写回 1）；
   CPU6 防饿 knob。现场：**R 落地 ✅，E5v2 整机重启 ❌（输出全 NUL）**。
   E5 系现场测试已停（对面 HANDOFF 有记录）。

## 5. E5 重启根因：已破案（mt76 设计 bug）+ 遗留一个问题

### 5.1 E5v2/E5R 重启 = 我的 bug，不是 framework 反制（已代码核实）

mt76 把写值放进 `TREE_RIGHT`（word1=child）。E5v1 值=0 → child=0 → 只有
STORE(a)，干净落地。**E5v2 值=0x10000 → child≠0 → CASE_A 额外执行 STORE(b)
`*(0x10000)=pc`——对未映射内核地址 0x10000 写入 → 同步异常 → 立即 panic →
整机重启**。这解释了 E5v2 的全部签名：输出全 NUL（不干净重启丢页缓存，连
一行 buffered 日志都没落盘）、死得远早于 v1、主动重启（新 boot id）vs v1 的
挂死。**E5R（值 0x10001）同样非法**——从未真正测过。

推论（重要）：**「保 initialized=1」的语义从未被现场检验过**——v2 死在写
本身。v1 黑屏根因（H-A framework 对 enforce=0 的反应 vs initialized=0 连带）
仍是**完全开放**的问题。

### 5.2 修法：E5v3 = child 用喷页地址（利用地址字节布局）

由 §3.2 基本约束，合法写值=0 或牺牲指针。巧解：**child=fake_lock（喷页零区
页对齐地址）**，其 8 字节地址值恰好是想要的字节布局：
- byte0=0x00（页对齐）→ **enforcing=0** ✓
- byte2=(addr>>16)&0xff ≠ 0（喷页在 0xffffff81xxxxxxxx）→ **initialized=1** ✓
- byte1=checkreqprot≠0（按请求 prot 检查，窗口期内无害）
- byte3..7=policycap 随机位（多数特性 policy 未用，低风险）
- STORE(b) `*(fake_lock)=pc` → 污染牺牲喷页 ✓（fake_lock 零区本来就是牺牲品）

**E5R（还原 enforcing=1）**：child=`fake_lock+1`（奇地址，arm64 非对齐写合法）
→ byte0=1 → enforcing=1，initialized 仍≠0。

这样 E5v3/E5R 都是「牺牲指针」形态，与 R 几何同构（R 7/7 无事故的结构性
保证）。**注意 fake_lock 需存在**（mt74 分支已有 `if (!fake_lock) abort` 守卫）。

### 5.3 判定实验（按成本排序）
1. **pstore（从未收集过，零成本，永远第一优先）**：`ls /sys/fs/pstore/; cat
   /sys/fs/pstore/console-ramoops* | tail -100` + `dmesg | grep -iE
   "watchdog|panic|Unable to handle"` → E5v2 的 panic 应有
   `Unable to handle kernel paging request at ...00010000`（H-B 终验）；
   v1 黑屏若有 system_server/watchdog 记录 → H-A 实锤。
2. E5v3 现场一轮（系统稳定后）：落地即 enforce=0 + initialized 保留 →
   观察 2-3 分钟。无黑屏 → v1 的问题是 initialized=0，E5v3 即最终形态；
   仍黑屏 → 反制针对 enforce=0 本身 → 只剩缩窗（E5v3→C+KO→E5R 背靠背）或
   弃 E5 走 §6.4。

### 5.4 H-C（风暴自诱导）备注
E5v2 是 R 落地后紧接的第二场 full storm，风暴自诱导不能完全排除；但 v2 的
死法（无输出+主动重启）与 v1（完整跑完+挂死）差异过大，H-B 已足够解释 v2。
v1 的黑屏仍可能是 H-A 或 initialized=0 连带，pstore 定分晓。

## 6. 下一步打法（新会话 playbook，按优先级）

### 6.1 静态（不动现场，第一优先）
- [ ] **写 mt78 补丁**：mt74 分支改为 E5v3 语义——`PSELECT_SELINUX_ENF_VALUE`
  语义重定义：`SPRAY`=child 用 fake_lock（推荐默认）、`SPRAY1`=fake_lock+1
  （E5R 还原）、数字仍按字面（保留但标注危险：非 0 非 `SPRAY*` 直接 abort
  并打原因，防再犯 §5.1 的错）。打印预期字节布局（enforcing/checkreqprot/
  initialized 三个 byte 值）供现场核对。
- [ ] 顺手核一遍 R 轮 STORE(b) 对 init_cred+0 的污染（§3.2）确无新影响
  （usage 巨大=防释放、uid 垃圾但 euid/caps 完好——已有推导，抽查即可）。

### 6.2 现场（等系统稳定 + 对面配合）
- [ ] **pstore/dmesg 取证**（重启后手机上第一件事，永远值得做，§5.3.1）。
- [ ] pkill 清残留（现场 HANDOFF 有命令清单）；load gate ≤15。
- [ ] E5 停跑直到 pstore 收到 + mt78 构建就绪。
- [ ] 零成本合并实验（可与任何 R 轮同跑）：预开 `/proc/<child>/status` fd +
  `dmesg | grep avc | grep -w kernel`（§6.3）。

### 6.3 无 E5 的替代验证路线（E5 若被 H-A 判死）
R+C 的成功本来就可能已被多次实现，只是被致盲。三个取证通道不依赖 E5：
1. **预开 fd**：父进程在 C 写前 open `/proc/<child>/status` 并保持 fd，C 后
   持续 read → 直接看 `Uid: 0 0 0`（绕过 ptrace_may_access 重查——打开时
   检查一次，fd 读写不重查）。
2. **mt73 sethostname("glroot")**：C 落地后子进程 sethostname（capable 用
   主观 cred=init_cred → 过；不碰文件系统 → 不受文件级致盲影响；SELinux 对
   sethostname 的 kernel SID 态是否放行 = 该实验同时验证的假设）。父进程读
   `/proc/sys/kernel/hostname`。
3. **dmesg avc 取证**：`dmesg | grep avc | grep -w kernel` —— C 轮后出现
   kernel 域 denied 即写落地+致盲理论铁证（历史轮可能已留下）。
   → 1+3 零风险零成本；若 C 铁证拿到，root 已在手上（euid=0+满帽），
   E5 的必要性只剩 KSU 加载，届时再权衡。

### 6.4 全链序列（mt78 就绪后）
R（CPU6，同轮带上 §6.3 的预开 fd + avc 取证）→ E5v3（SPRAY 默认）→
C+KO 背靠背（`PSELECT_TASK=<R-child>` + `PSELECT_KO`）→ E5R（SPRAY1）。
判据：`/proc/<R-child>/status` Uid:0 + root_alive.txt + hostname=glroot +
ksu_done + pstore。**每步之间清 env 残留**（mt51 误触发教训：上轮
stage/PSELECT_TASK 会监控旧 child）。

## 7. 代码与文件地图

- `research/mt11_v30_src/main.c` — 核心利用。env knobs：`PSELECT_CRED`（开
  cred 链）、`PSELECT_PTR_MODE/PTR_PC_OFF(0x770=R/0x778=C)`、`PSELECT_PTR_PI`
  （E4 pi_tree）、`PSELECT_PTR_VALUE/PTR_TARGET_OFF`、`PSELECT_TASK`（external
  单进程模式）、`PSELECT_SELINUX_ENF(+_VALUE)`（E5/mt76）、
  `PSELECT_CONSUMER_CPU`（mt77 防饿）、`PSELECT_PTR_STRICT`（AND-gate）、
  `PSELECT_KO`（finit_module）。
- `slide.c` — slide pselect + fdset 编码 + consumer；mt66 窗口/看门狗。
- `scripts/` — `disasm.py`（反汇编）、`find_state_xrefs.py`（selinux_state
  引用扫描）、`find_offset_access.py`、`dump_task_fields.py`、`mt_elf.py`
  （公共 ELF 解析库）。
- `CHECKPOINT_e5_geometry_20260904.md` — E5 几何全套（§六现场复盘、§八黑屏
  排除、§九 mt76 方案）。
- `CHECKPOINT_detection_artifact_20260904.md` — C 悖论解（致盲理论）。
- `CHECKPOINT_C_stage_paradox_20260901.md` — C 指令级分析 + E4 设计。
- `bin/mt77/` — 最新现场二进制。`logs_raw/20260905_mt77_e5v2_reboot/` —
  最新一轮（R 成功 + E5v2 重启）。
- 历史 HANDOFF：`HANDOFF_2026-09-02.md`、`HANDOFF_2026-09-05_mt77.md`（现场侧）。

## 8. 红线（不可忘）

- root 成功后**不得**用 root 权限对手机做任何操作（用户原话）；KSU/insmod
  是否进行需用户另行授权。
- 现场：E5 系停跑直到根因判定；load gate ≤15；每轮清残留进程；屏幕常亮插电。
- 不要重做 §3 已验证事实；不要在未看 pstore 前盲跑 E5。
