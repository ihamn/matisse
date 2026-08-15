# 外部评审最终结论 — matisse GhostLock (CVE-2026-43499)

> 评审人: 独立 AI (非项目历史参与者)
> 日期: 2026-08-16
> 本文件按 REVIEW_TASK.md 要求产出，取代并修正我此前的 EXTERNAL_REVIEW_AI_2026-08-16.md。
> 方法: 全部结论回溯到源码行号 / 反汇编 / kallsyms 符号独立复核；**包括修正我自己前一份评审中的两处误判**。

---

## 0. 最重要的三个新结论（本次评审增量）

### 结论 A: 写入值不是 "tree_pc 派生"，而是 tree_right / tree_left 本身 — 项目和我此前的理解都错了

按 `ref/rb_erase.asm` 逐指令复核 5.10 `__rb_erase_augmented`，`__rb_change_child` 落地的那条 store 是：

```
[parent + 8] = child
```

而 `child` 的取值（node = 假 waiter 的 tree_entry，w0/w1/w2 = parent_color/rb_right/rb_left）：

| 条件 | child | 落地写入 | 附带 store |
|---|---|---|---|
| w2==0 (左空) | **w1** (tree_right) | `[target] = tree_right` | `[w1] = w0`（把值当地址写，w1 必须是可写内核地址） |
| w1==0 (右空) | **w2** (tree_left) | `[target] = tree_left` | `[w2] = w0`（同上） |
| w1==0 且 w2==0 | NULL | **`[target] = 0`（单条干净零写）** | **无**（pc bit0=0 即 RED 时 rebalance=NULL） |
| w1≠0 且 w2≠0 | successor | 需解引用 `[w1+0x10]` | 多条，高危 |

**即：fd_set 里的 word1(word2) 就是写进目标的值。** "审视_Case1写不了任意值.md" 的"只能写 tree_pc 派生值"不成立；我前一份评审 §2.2 虽然推对了 store (a) 的值是 tree_right，但把 mt25 的落值 `0x...7700` 归因为 "tree_pc&~0xff" 是错的（见结论 B）。

### 结论 B: mt25/mt26 的观测值有了更简单的一致解释；"负 shift 决定性突破"方向很可能是浪费

- **mt26 (Permissive, 不崩)**: 唯一能同时解释 "enforcing 变 0" + "不崩" 的形状是 **w1=0 ∧ w2=0 ∧ tree_pc bit0=0 (RED)** → 单条 `[enforcing]=0`，无附带写、无 rebalance。这说明 mt26 那次运行时 tree_right 恰好是 0（当时二进制的默认值，或版本差异）。**"精确零写"原语其实已经在真机上被证明过一次 — 就是 mt26 的 Permissive。**
- **mt25 (boot_id 变 `00778a02-...`)**: 落值低 32 位 = `0x028a7700`，不是 tree_pc(`...77c8`) 也不是当前源码的默认 tree_left(`SLIDE_RANDOM_BOOT_ID_DATA=0xffffff80028a77d0`, target.h:77)。三个候选都差低字节 → **当次运行的二进制里有个默认词的值是 `0x...7700`**（旧版常量？旧默认值？）。身份待定，但不影响结论 A —— 它是"某个 fd_set 词的值被原样写入"，进一步支持值语义模型。
- **推论**: "负shift_决定性突破.md" 的计划（扫 -14..+7）建立在我们以为 shift=0 几何错位的前提上。但值形状错误（没人知道 TREE_RIGHT/TREE_LEFT 就是写入值 + 当前源码 TREE_RIGHT 默认=fake_lock 污染所有 Case-1）已经足以解释全部失败。且 matisse 代码 `slide.c:45` 对 `global_word<0` 直接不放置 → **负 shift 时 tree_pc 根本不会被摆上栈，扫负 shift = 保证读到垃圾**。在"每 boot 只许 ~2 测"的约束下，这个扫描计划应当冻结。

### 结论 C: mt44 的"写 uid 失败"最可能是打错偏移 — 修复只需一行

mt44 cred 模式 (`main.c:607-637`) 的实际形状：

```c
uintptr_t cred_uid_ptr = cred_addr + 0x4;          // ← 用了 uid@+0x4 (mt41 getuid 推测)
snprintf(pc_env, ..., cred_uid_ptr - 8);           // TREE_PC = cred-4
setenv("PSELECT_TREE_RIGHT", "0", 1);              // w1 = 0 ✓
setenv("PSELECT_TREE_LEFT", "0", 1);               // w2 = 0 ✓  → 正是"干净零写"形状
```

形状完全正确！但项目自己的另外两处都指向 **uid@+0x14**：`target.h:147` `CRED_UID_OFF 0x14`（commit_creds 反汇编）、`util.c` mt35 假 cred 也是 uid@0x14。**mt44 用 +0x4 在 cred+4..cred+0xb 写零 → 若真偏移是 0x14，写入落在别的字段 → getuid 不变 → "失败"是必然，且完全不能证伪原语。**

---

## 1. 项目卡在哪（修正后的判断）

前一份评审把"栈几何 PSELECT_SHIFT 未定标"列为第一卡点。本次修正为：

**第一卡点 = 写入值语义从未被正确建模（现已建模，见结论 A），它污染了所有后续实验的解释。**
- 当前源码 `slide.c:116` tree_right 默认 = fake_lock（喷页地址）→ 任何不显式设 `PSELECT_TREE_RIGHT=0` 的 Case-1 运行，写入值都是喷页地址（低 32 位是垃圾 uid）。
- mt32-34 "写 task->cred=init_cred 必崩"：那是 w1=init_cred（非零 child）→ 附带 store `[init_cred] = w0` 直接踩 init_cred.usage → cred 生命周期 BUG_ON。**崩溃原因不是"指针写不行"，是值形状选错** —— 换成 w1=0∧w2=0 的零写就没有附带写。
- mt28b/d "落值=tree_pc 原始值" = 结论 A 表格第 2 行的附带 store（`[w2]=w0` 写到了可观测地址），不是主 store。

**第二卡点 = cred 目标身份与字段偏移未定**（cred_cand 是不是 cred；uid@0x4 vs 0x14）。
**第三卡点（降级）= 栈几何未定标**：mt26 在 shift=0 下成功过一次（同 boot 两中），说明该编译产物下 shift=0 至少"能"对上；errno=110 的轮次更可能是触发时序而非几何。几何仍是未验证假设，但不再是最优先。

## 2. 未验证假设清单（增量更新）

| # | 假设 | 状态 |
|---|---|---|
| A2' | "落值 = tree_pc 派生" | **证伪**（前评已判，本次给出正确模型: 落值 = child = w1/w2） |
| NEW | mt26 成功 = w1=w2=0 单条零写 | 高置信但间接（反演自观测）；一次特征值实验可直接证实 |
| A5 | cred_cand 是 struct cred | 仍未证实；mt44 失败不构成证伪（偏移错） |
| A6 | uid@+0x4 vs +0x14 | 代码内自相矛盾；需 BTF 或反汇编工件裁决 |
| NEW | mt25 落值 0x...7700 的身份 | 待原始日志/旧 .so 定案 |
| A1 | shift=0 几何正确 | 未验证但优先级下调（mt26 一中 + 值形状已能解释其余失败） |

## 3. 下一步（按优先级，前两项不占设备测试额度）

### P0-A: 修 mt44 的偏移并轮扫四个窗口（一次设备运行裁决 A5+A6+原语三件事）

`main.c:607` 一行改掉，让重试循环轮扫候选窗口（覆盖两种偏移假设的所有可见字段）：

```c
/* mt45: rotate uid-window candidates across attempts (covers uid@0x4 and uid@0x14 layouts) */
static const uintptr_t uid_wins[] = { 0x14, 0x4, 0x1c, 0x24 };  /* euid/uid/suid/sgid candidates */
uintptr_t cred_uid_ptr = cred_addr + uid_wins[(att - 1) % 4];
```

子进程判定同步升级（`main.c:578` 只查 getuid 不够，euid/fsuid 变了 getuid 不动）：

```c
/* child: after wake, print all id fields — any zero field = identity+offset confirmed */
pr_info("child ids: uid=%d euid=%d suid=%d fsuid=%d gid=%d egid=%d\n",
        getuid(), geteuid(), getresuid(NULL,NULL,NULL)==0?0:0 /*用 getresuid 三参*/, ...);
/* 简单版: 直接读 /proc/self/status 的 Uid:/Gid: 行打印 */
```

判读矩阵：
- 任一字段变 0 → **cred 身份 + 偏移 + 零写原语三合一证实**，且变零的字段名直接告诉我们真实布局；
- 4 窗口全无变化且 boot_id 观测词（加一个 `PSELECT_CRED_BOOTID` 轮）也无变化 → 写没落地 → 回到几何/触发排查；
- 观测词变化但 id 不变 → cred_cand 不是 cred（A5 证伪）→ 转 mm_struct 等排除。

### P0-B: 冻结"负 shift 扫描"计划，理由入档

`slide.c:45` 负 global_word 不放置 + 值形状已解释失败 + 每 boot 仅 ~2 测额度。若未来要支持负 shift，必须先改放置逻辑（负词落到前一组的对应位置），那是几何定标之后的事。

### P1: 补齐仓库（缺的都在 §4）— 尤其是 ELF 和原始日志

### P2: 几何静态定标（GEOMETRY_ANALYSIS.md 的待补部分）

有 ELF 后 10 分钟可完成：反汇编 `__arm64_sys_pselect6`(0xffffffc00856f794, 到 0xffffffc00856f960) 与 `__arm64_sys_futex`(0xffffffc008299e5c, 到 0xffffffc00829a114) 两条 syscall 入口链，公式：

```
shift = (0xe0 + D_futex - 0x50 - D_select) / 8
   D_* = syscall 入口到目标帧的完整帧深（含 wrapper）
```

另两个顺手的加固（都是一行级）：
1. `slide.c:232` 的 `pselect()` 走 bionic 包装，路径不确定 → 改 `syscall(SYS_pselect6, ...)` 直调，钉死内核路径（避免走 `__arm64_sys_select` 的歧义）。
2. `slide.c:396` FWRQ 返回后、pselect 前那次 `FUTEX_UNLOCK_PI` 会在 overlay 之前产生一次 PI 活动 → 挪到 pselect 之后，消除窗口期不确定性。

### P3: 拿到 root 后的链路（不变）

uid/gid 系列四窗口零写 → （caps 需要非零值写 = w1=可写内核地址，天然受限；优先验证 Permissive + uid0 下 `insmod` 是否已可行，不可行再评估 task->cred=init_cred 的 w1=init_cred 附带写风险）。

## 4. 缺失清单（阻塞上述工作，请补进仓库）

| # | 缺什么 | 为什么缺它不行 |
|---|---|---|
| 1 | **kernel_with_symbols.elf / kernel_edata.Image** | GEOMETRY_ANALYSIS.md 就是从它量出来的，但文件不在仓库。没有它无法完成 PSELECT_SHIFT 定标和任何反汇编复核 |
| 2 | **原始运行日志** mt22/mt25/mt26 的 .txt（手机 `/sdcard/Documents/matisse_backup_essentials/logs/`），不是摘要 .md | mt25 落值 `0x...7700` 身世、当次 fake_lock/page_base 实际值、env 是否生效，全在里面 |
| 3 | **实机 .so**（preload_mt25.so / mt26 / mt44） | 档案里的源码 ≠ 当天跑的二进制（TREE_RIGHT 默认值的历史版本差异只有二进制能回答） |
| 4 | **BTF 检查结果**：`ls -l /sys/kernel/btf/vmlinux`（shell 一条命令，零风险） | 若可读 → cred/task_struct/rt_mutex_waiter 全部字段偏移一查定音，A6 直接消失 |
| 5 | **commit_creds / getuid / setresuid 反汇编摘录**（哪条指令、哪个偏移） | uid@0x4 vs 0x14 三个"铁证"互相矛盾且无工件 |
| 6 | （可选）mt32-34 cred 崩溃轮的 pstore/dmesg | 验证"附带 store 踩 init_cred.usage"的崩溃机制解释 |

## 5. 给监工的直白总结

- 写原语（往内核任意地址写 8 字节零）**大概率已经成立** — mt26 把 SELinux 翻成 Permissive 那次就是它，当时没人意识到。
- mt44 距离 root 可能只差**一行偏移**（0x4 → 0x14 轮扫）。
- "负 shift 扫描"先停，那是在错误的诊断上花宝贵的真机额度。
- 下一步要么补 §4 的 1/2/3 让我把历史定案，要么直接上 P0-A 的修正版实验（一行改动 + 判读矩阵），一轮跑完同时回答三个问题。
