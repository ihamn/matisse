# 外部独立评审 — matisse GhostLock (CVE-2026-43499) 项目

> 评审日期: 2026-08-16
> 评审范围: 本仓库全部档案（含 e1a597a / 0072009 两个新提交）、`research/mt11_v30_src` 源码、
> `ref/rb_erase.asm` 反汇编、`research/rtmutex_src`（真机 rtmutex/rbtree 源）、上游 ghostlock-oneplus 源码、
> `research/kallsyms.txt`（142102 符号）、全部 logs/*.md 与 CHECKPOINT/AI_ARCHIVE。
> 方法: 不采信任何日志结论，每条关键断言都回溯到源码/反汇编/符号表独立复核。
> 结论分四层: 卡点、未验证假设、下一步、仓库本身的缺口。

---

## 0. 结论速览 (TL;DR)

1. **写原语真实成立**（mt22/25/26 一手证据 + 我对反汇编的独立复核均支持）——这不是卡点。
2. **真正的卡点是"栈几何未定标"（PSELECT_SHIFT）**: 假 waiter 与 pselect fd_set 的字对齐从未在"修好的触发"下测过。
   它能同时解释: 命中率只有 10-25%、`futex trigger errno=110`（walk 读不到假 waiter）、Case-2 "时灵时不灵"、
   以及**落盘的写入值从来对不上按字表推演的值**（我核对 `mt26` 成功案例发现: 按 5.10 rb_erase 反汇编，
   写入值应为 `tree_right`（默认 `fake_lock = page_base+0x1350`，低字节 0x50），但实测 enforcing 低字节=0
   → 落地的 store 不是按字表建模的那个 store）。
3. **最后一晚的两条"定论"都建立在未定标几何之上**: "Case-1 写不了任意值" 与 "必须走 Case-2" 均未获反汇编支持。
   按 `ref/rb_erase.asm`，Case-1 本身就有两个 store，其中 `[parent+8] = child` 的 child 就是 `tree_right`（完全受控值）；
   且 **w1=w2=0 + parent RED 位=0 时是单条干净 store `[target]=0`、无 rebalance、无第二写** —— "精确写 0"可能早就可用，
   `v23_10` 的全零崩溃黑名单不能反驳它（那次未控色位/未定标）。
4. **路线 C（perf 泄露 cred + 写 uid 字段）方向正确但卡在身份未证实**: `cred_cand` 高度符合 cred 特征，
   但决定性实验（写 uid 字段看 `getuid`）从未跑成；且日志内部对 uid 偏移自相矛盾（+0x4 vs +0x14）。
5. **仓库快照滞后于实验**: 源码停在 mt32 时代（无 PSELECT_PERF_CRED / OBS_ONLY / setresuid 采样代码），
   脚本停在 mt28g，无任何二进制——mt33~mt44 共 12 小时的关键实验全部不可审计、不可复现。

---

## 1. 时间线复核（一手证据锚定）

| 阶段 | 时间 | 事实 | 我的复核 |
|---|---|---|---|
| v 系列 / R 系列 | 7 月 | FOPS 覆写死路（rb_erase csel 永写 parent+8）；R 系列 shape=0 读 percpu 必崩 | ✅ 与 `MT论坛求助_项目完整梳理.md` 一致；且 8-14 审计补了更根本的原因: FOPS 路线**结构性无 UAF**（无 requeue → 无悬垂 waiter） |
| v37/v38 trigger_stamp | 7-16~21 | EDEADLK+栈喷可行（NULL task 崩 = stamp 落点正确） | ✅ `CHECKPOINT_v37/v38` |
| kallsyms 全量提取 | 8-14 | 142102 符号，RVA 全核对（selinux_enforcing 差 1 字节被纠正） | ✅ 我抽查 `research/kallsyms.txt`: init_task=0xffffffc00a79bec0、init_cred=0xffffffc00a7b0ae0、ashmem_misc=0xffffffc00a8e76d8，与 target.h 完全一致 |
| oracle 阴性→破案 | 8-14 深夜 | FOPS 路线无 UAF；真触发 = SLIDE 路线 + **futex_lock_pi 触发** | ✅ `AI_ARCHIVE_2026-08-14_kallsyms_verified.md` |
| **mt22 写原语实证** | 8-15 02:2x | boot_id 被改写 + 自发持续写 | ✅ 决定性节点 |
| mt25/mt26 | 8-15 晨 | 写 boot_id、写 enforcing → round4 Permissive | ✅ `scripts/test_mt25.sh`/`test_mt26_selinux.sh` env 与日志吻合 |
| Δ=0 证明 | 8-15 午 | 双目标命中 ⇒ 地址公式无偏移 | ✅ 逻辑成立（两个不同 dmap 目标都写中） |
| cred 指针路线 | 8-15 下午 | TASK_CRED_OFF 0x820→0x780（commit_creds 反汇编）；写 task->cred=init_cred 必崩（mt32-34） | ⚠️ 机制分析（cred 生命周期 BUG_ON）合理，但反汇编工件不在仓库，不可复核（见 §3-A6） |
| 路线 C | 8-15 晚 | perf 采样 setresuid（x19=cred）→ cred_cand 稳定、每进程独有（mt39/41）；mt44 写 uid 失败 | ⚠️ 采样方法合理；mt44 失败根因未定（最后一晚归到 shift 未定标 + Case-1 值语义） |
| 最后三份日志 | 8-15 23:0x~23:3x | shift 从未在 mt22 修复后重扫；负 shift 被硬编码拒绝；Case-1 写不了任意值 | ✅ 前两条我在源码级证实；**第三条我证伪**（见 §2.2） |

---

## 2. 核心判断: 项目卡在哪

### 2.1 第一层卡点（根因）: 栈几何 PSELECT_SHIFT 未定标

这是唯一能统一解释所有异常的假设，证据链:

1. **上游把 shift 当 per-device 参数**: ghostlock README 明确 waiter 落点由编译器输出（PGO+LTO）决定，
   `PSELECT_SHIFT` 支持 **-14..+14**（`ghostlock_src/.../fops.c:104`: `env_int_range("PSELECT_SHIFT", PSELECT_WAITER_WORD_SHIFT, -14, 14)`），
   OnePlus 13 需要 -2、Find X9 Ultra 需要 -8（且后者因字段落在非零 fds 指针上而**结构性不可行**）。
2. **matisse 适配版把这条路堵死了**: `research/mt11_v30_src/slide.c:136-141` 硬编码 `pshift<0 || pshift>20 → 0`。
   负 shift 从未可能被测试。更隐蔽的是: matisse 自己的 `target.h:17` 定义了 `PSELECT_WAITER_WORD_SHIFT 1`
   （上游用它做默认 shift），但整个 matisse 源码树**没有任何代码消费这个宏**——它是死配置，即"shift=1"这个默认值也从未生效。
3. **唯一一次 0-7 扫描前提已失效**: `logs/历史shift结论_修正.md` 已自我纠正——mt16 的扫描在 mt22 触发修复**之前**，
   修复后所有版本（mt25/26/29/40/44）都固定 shift=0。mt26 的成功完全可以是"shift=0 偶然对齐了那次 boot 的布局"。
4. **值语义对不上 = 几何错位的直接物证**（这条是我的独立发现，详见 §2.2）: 按 5.10 `rb_erase` 反汇编推演，
   mt25/mt26 落地的写入值与按字表（w0/w1/w2）建模的值**不相等**——说明真正执行的 erase 读到的字与 fd_set 里摆的字错位。

### 2.2 第二层卡点: 写入值语义从未与反汇编对账（最后一条"定论"是错的）

按 `ref/rb_erase.asm`（真机反汇编）复核 5.10 `__rb_erase_augmented`:

```
node = 假 waiter 的 tree_entry (w0/w1/w2 = parent_color / rb_right / rb_left)

Case-1 (w2==0, w1!=0):  两条 store
  (a) __rb_change_child: 读 [w0&~3 + 0x10] 与 node 比对(永远不等) → [w0&~3 + 8] = w1   ← 值 = tree_right, 完全受控!
  (b) child->__rb_parent_color = pc → [w1] = w0(原始值)                                 ← 把值当地址的副作用写

Case-1 (w2==0, w1==0):  child=NULL → 无 (b);
  rebalance = (pc bit0==1) ? parent : NULL
  → w0 的 bit0=0 (RED) 时: 仅一条 store [w0&~3+8] = 0, 无 rebalance, 无副作用   ← ★ 精确写 0 原语

Case-2 (w2!=0, w1==0):  只有左孩子
  [w2] = w0(原始值) (rb_set_parent); rebalance 恒为 NULL   ← 值 = tree_pc 原始值

Case-3/4 (w1!=0 且 w2!=0): 先解引用 [w1+0x10] (successor 搜索) → w1 必须是可读内核地址
```

对照实测:

| 实验 | 字表建模的落值 | 实测落值 | 匹配? |
|---|---|---|---|
| mt25 写 boot_id | (a): fake_lock = base+0x1350（低字节 0x50） | 0xffffff80028a7700（= tree_pc & ~0xff） | ❌ |
| mt26 写 enforcing | (a): fake_lock（低字节 0x50 → Enforcing） | 低字节 0 → **Permissive** | ❌ |
| mt28b/d | — | 落值 = tree_pc 原始值 0x...77c8 | 对应 (b)/Case-2, 不是 (a) |

**结论**: 落地的 store 不是按字表建模的 (a)。三种日志对落值的描述（`tree_pc&~0xff` / `tree_pc` / "tree_pc 派生"）
互相不一致，正说明没人知道是哪条 store 落的——这就是几何错位的物证。
由此推出的两条"定论"不成立:
- ❌ "`审视_Case1写不了任意值.md`" 的 "Case-1 忽略 WRIGHT、只能写 tree_pc 派生值" —— 反汇编不支持;
  (a) 的值就是 `tree_right`（受 TREE_RIGHT env 控制）。
- ❌ "写精确 0 必须 Case-2" —— Case-1 的 w1=w2=0 + RED 分支就是单条干净 `[target]=0`；
  `v23_10` 的全零崩溃不能反驳（该轮未控色位、未定标几何，且可能走了 pi-tree erase）。
  反而 **Case-2/3 要写值 0 有结构性困难**: 值来自 w1/w0，但 Case-3/4 会解引用 w1（=0 即 NULL deref），
  Case-2 的落值是 w0 原始值（要为 0 则 parent=NULL → change_child 改写 root，root 位置取决于走哪条 erase）。

### 2.3 第三层卡点: cred 目标识别未完成 + 偏移自相矛盾

1. `cred_cand`（setresuid x19 采样）: 每进程独有 + 轮内稳定 + 26/256 票 —— 符合 cred 特征，
   但 mm_struct 等同 slab 每进程对象同样满足（`logs/mt37_perf候选_观察结果.md` 自己也承认）。
   决定性实验（`logs/mt41_纯观察_cred_cand确认.md` 计划的"写 uid 字段看 getuid"）从未跑成（mt44 失败，归因回到几何）。
2. **日志内部矛盾未解决**: `logs/cred内部偏移_反汇编真值_结论.md` 说 uid@+0x14（commit_creds），
   `logs/mt41` 说 real uid@+0x4（getuid），`logs/路线C_完整攻击链设计_mt39.md` 列 +0x4/+0x14/+0x1c/+0xc。
   三个"反汇编铁证"互相打架，且**都不在仓库里**。怀疑 RANDSTRUCT 重排是合理的，但没有工件无法裁决。
3. 就算 getuid()==0: 只改一个 uid 字段 ≠ root（还有 euid/suid/gid 系列 + caps）。
   字段不连续 ⇒ 内容写路线需要多次独立写，每写一次都是一次风险——这应该进路线决策，日志没算这笔账。

### 2.4 第四层（工程因素，真实但非根因）

- MTK slab 脆弱: 每次重启后 ≤2 次测试（多份 checkpoint 一致记录）。
- 悬垂链自发写: 测试后链不过夜（sidtab 损坏事故，`HANDOFF` 已列入教训）。
- FUSE 全零文件 / rish namespace / Shizuku 间歇超时: 已有 deploy.sh 哈希铁律等对策。

---

## 3. 未验证假设清单

| # | 假设 | 状态 | 我的核查结果 |
|---|---|---|---|
| A1 | 假 waiter 落点 = shift 0 对应的位置 | **未验证** | mt16 扫描前提失效; 负 shift/shift=1 从未测; 上游同族设备默认值都不是 0 附近无据 |
| A2 | "Case-1 落值 = tree_pc 派生" | **证伪** | 反汇编: (a) 落值 = tree_right; 实测值与所有建模不符 ⇒ 几何错位 |
| A3 | "写精确 0 必须 Case-2" | **存疑(反向)** | Case-1 w1=w2=0+RED 即单条干净写 0; v23_10 不构成反驳 |
| A4 | Case-2 任意值写"不稳定/危险" | 未验证 | 全部 Case-2 实验也在 shift=0 下跑的; 不稳定可能全是几何的表象 |
| A5 | cred_cand 是 struct cred | 未验证 | 特征符合但非唯一; 决定性写实验未跑成 |
| A6 | TASK_CRED_OFF=0x780 / real_cred@0x778 / uid@+0x4 或 +0x14 | 无法复核 | 工件(反汇编摘录)不在仓库; 三份日志互相矛盾 |
| A7 | KASLR=0、Δ=0、关键符号 RVA | **已验证** ✅ | kallsyms.txt 抽查一致; 双目标写中证明 Δ=0 |
| A8 | 5.10 写 task->cred=init_cred 必崩（cred 生命周期） | 机制可信 | 与 `research/kernel/cred.c` 的 BUG_ON/put_cred_rcu 一致; 但"解法=写内容"还依赖 A5/A6 |
| A9 | "Permissive 有助诊断" | 部分成立 | dmesg 解锁 ✓; 但 kptr_restrict 掩码与 SELinux 无关（delta 文档自己也记了） |
| A10 | "futex trigger errno=110 ⇒ walk 没执行" | 解释有风险 | 110=ETIMEDOUT 只说明 FLPI 超时; walk 是否运行需独立观测（如自发写/标记） |
| A11 | 快照即现状（README_EXTERNAL_REVIEW: mt11_v30_src = current source） | **不成立** | 源码停在 mt32 时代; mt33-44 的代码不在仓库; 无二进制 |

---

## 4. 下一步最该做什么（按优先级; 标注是否需要设备）

### P0 — 无设备、零风险、决定后面一切

1. **静态几何定标，替代盲扫**。仓库里已有全部原料: `ref/` 的 kernel_with_symbols.elf（含符号）+
   kallsyms RVA。归档里已经量到 `futex_wait_requeue_pi` 帧内 rt_waiter@sp+0x70、`core_sys_select`
   stack_fds@sp+0x50，缺的只是把 `sys_pselect6→core_sys_select` 与 `sys_futex→futex_wait_requeue_pi`
   两条 syscall 路径的完整帧深算完，得到精确的 word 偏移。同时必须做上游同款的**可行性检查**:
   waiter 的 tree 字段落点是落在 fd_set 可控字上，还是落在非零的 fds 指针数组上（Find X9 Ultra 就是死在这）。
   输出: 精确 shift 值（含正负）+ 可行/不可行判定。这比在"每 boot 只许 2 测"的约束下盲扫 29 个 shift 值优越一个数量级。
2. **对账写入值语义（一次实验设计好）**: 定标后跑一次 mt25 配方（boot_id 观测），TREE_RIGHT 显式设一个
   特征值（如 0x4142430000000000|0x00），验证落值是否精确等于 TREE_RIGHT。相等 = 几何对齐 + Case-1(a) 语义确认;
   这一个实验同时裁决 A1/A2 两条假设。
3. **补齐仓库**（外部评审可用性）: 提交 mt33~mt44 的源码与测试脚本、关键反汇编摘录
   （commit_creds/setresuid/getuid）、至少最后几个 .so（mt25/mt26 成功版、mt44 失败版）。
   没有这些，最后 12 小时的所有结论都无法审计。`CVE-2026-43499_ref` 子模块也缺失（需 --recursive 拉取）。

### P1 — 设备侧、低风险（每项 ≤2 次运行）

4. **BTF 一查定音**: `tools/extract_btf.py` 在仓库里躺了整个项目周期却从未见于任何日志。
   先 `ls -l /sys/kernel/btf/vmlinux`（shell 即可）——若可读，cred/task_struct/rt_mutex_waiter 的
   全部字段偏移（A6 的 0x4 vs 0x14 vs 0x780）一次出清，不需要任何 exploit 运行。
5. **Case-1 精确写 0 复测**: 几何定标后，w0=boot_id-8（bit0=0）、TREE_LEFT=0、TREE_RIGHT=0 →
   预期 boot_id 首 8 字节精确变 0x0。若干净（不崩、无自发写），"精确 0 写"原语成立，
   路线 C 不再需要 Case-2（绕开 A4 的全部不稳定性和 successor 解引用约束）。
6. **cred 身份决定性实验**（mt41 原计划）: `[cred_cand + uid_off] = 0`，观察 `/proc/self/status` 的
   Uid: 四个字段（区分 real/effective/suid + 顺带确认对象身份），PSELECT_RETRY=1。
   注意不止看 getuid()——status 一行能同时裁决字段身份与对象身份。

### P2 — 打通链路

7. cred 内容补全: uid/gid/euid/egid/fsuid/fsgid + 4 组 caps（每字段一次写; 若 BTF 可用可找 8 字节窗口一写双字段）
   → `setenforce 0` → insmod kernelsu.ko。保持"先 Permissive（mt26 配方）再冒险"的安全网顺序。
8. 悬垂链卫生: 每轮系列后主动消解（让 W 线程干净退出/受控二次写失效化），替代目前"靠重启清理"的被动纪律。
9. 低成本对照: diff matisse 的 `slide.c` 与新提交里各 target 的 469-613 行版 `slide.c`
   （如 stallion 版有 boot_id "shifted leak" 恢复逻辑），排查除负 shift 外还有哪些上游特性在移植时被丢掉。

---

## 5. 仓库快照本身的缺口（提交 0072009 之后仍存在）

1. `research/mt11_v30_src` 滞后于日志 12+ 小时（无 perf-cred/OBS 代码）; README_EXTERNAL_REVIEW 的
   "current exploit source" 指引会误导后续评审。
2. 无任何编译产物与 mt29+ 测试脚本; `scripts/` 止于 mt28g，而 HANDOFF 引用的 `run_mt26e.sh` 也不在。
3. `research/duchamp-root/` 是空目录; `duchamp_src` 无 cred 相关策略——没有可借鉴的 MTK 兄弟成功案例。
4. 结论类文档存在多处已被后续推翻但未标注废弃（例如 `!!!_AI_READ_THIS_FIRST.md` 停在 7-16 v34 状态，
   与 8 月状态差异巨大）——建议按时间加"已被 X 修正"戳。

---

## 6. 一句话总结

**项目不是卡在"能不能写"（写原语已实证），而是卡在"写进去的字到底是谁"——栈几何从未定标，
导致值语义、Case 选择、cred 目标三层的所有结论都建在浮沙上。先把 PSELECT_SHIFT 用静态反汇编算准
（零设备风险），再用一个 boot_id 特征值实验对账值语义，然后用 Case-1 全零分支拿"精确 0 写"，
cred 身份实验随之水到渠成——链路后半段（caps/insmod）反而是工程问题。**
