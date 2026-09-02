# C 阶段悖论：指令级应写而实测不写（2026-09-01 深度反汇编）

> 背景：R 阶段（写 task+0x778 real_cred）7/7 落地；C 阶段（写 task+0x780 cred）0/N 全灭
> （external/fork × 51ms/2s/17.5s 进窗全组合，见 `logs_raw/20260901_c_geom_decisions/`）。
> 本文用设备内核 `ref/kernel_with_symbols.elf`（boot bf1c84d3）逐指令反汇编，给出
> "C 几何在指令级必然写 0x780"的证明，与实测 0/N 构成**结构性矛盾**，并给出
> 绕开该悖论的 E4 pi-tree 备用几何 + 下轮取证实验设计。

## 一、几何模型（写入原语）

fake waiter（喷页）word 布局（5.10 flat 10-word）：

| word | 字段 | erase 语义 |
|---|---|---|
| 0 | tree_entry.__rb_parent_color | parent 指针（低 2 位颜色） |
| 1 | tree_entry.rb_right | CASE_A 的 child（写入值） |
| 2 | tree_entry.rb_left | ==0 时走 CASE_A |
| 3-5 | pi_tree_entry pc/right/left | PI 树 erase |
| 6-9 | task/lock/prio/deadline | 链路字段 |

写入目标 = `word0 & ~3` 的 +8 或 +16（由 `__rb_change_child` 分支决定）。

- R：pc=task+0x770 → 写 0x778(real_cred) 或 0x780(cred)
- C：pc=task+0x778 → 写 0x780(cred) 或 0x788(未知字段)

## 二、rb_erase 指令序（0xffffffc008a71228，导出符号实证）

```
paciasp
ldp  x8, x9, [x0, #8]     ; x8 = node->rb_right (word1), x9 = node->rb_left (word2)
cbz  x9, CASE_A           ; word2==0 → 无左子路径（我们的配置：TREE_LEFT=0）
; （两子全非空才走 successor 路径，与我们无关）

CASE_A:
ldr   x9, [x0]            ; x9 = word0 = pc（含颜色位）
ands  x10, x9, #-4        ; x10 = parent = pc & ~3
b.eq  ROOT_PATH           ; parent==0 → 树根路径（我们 pc 非 0，不走）
mov   x11, x10
ldr   x12, [x11, #0x10]!  ; ★检查 parent->rb_left (+16) == node？
sub   x13, x11, #8        ; x13 = parent+8 (rb_right 槽)
cmp   x12, x0
csel  x11, x11, x13, eq   ; eq→写 parent+16 / ne→写 parent+8
str   x8, [x11]           ; ★STORE(a): *(目标槽) = word1
cbz   x8, 0x360           ; child==0 才走深 rebalance 判断
mov   x10, xzr            ; child≠0 → rebalance = NULL（无再平衡！）
str   x9, [x8]            ; ★STORE(b): *(word1+0) = pc（child 继承色）
```

**要点：先查 `rb_left(+16)`，不等才写 `rb_right(+8)`；child≠0 时无 rebalance，双 store 都执行。**

## 三、R 成功机制（完全自洽）

- R：parent = task+0x770。检查 `*(task+0x780)` = cred 真实指针 ≠ 喷页 node → **ne** → 写 `*(task+0x778)` = word1 = init_cred 别名（0xffffff80027b0ae0）。
- 验证 CapEff 读的是 real_cred：`proc_pid_status` @ 0xffffffc008666f0c 内联 task_cap：
  ```
  add  x9, x22, #0x778    ; &task->real_cred
  ldar x9, [x9]           ; RCU 读 real_cred
  ldr  x9, [x9, #0x80]    ; cred->cap_effective @ +0x80
  ```
  → Rfork2 落地后 CapEff=000001ffffffffff（init_cred 满帽）与"写 0x778"闭环 ✓
- STORE(b)：`*(init_cred+0) = pc(task+0x770)` → usage=低32位（巨值护身符）、uid=高32位（0xffffff80），无害，与注释实证一致。

## 四、C 几何的指令级结论：必然写 0x780（矛盾确立）

- C：parent = task+0x778。检查 `*(task+0x788)`：
  - **0x788 不是 comm**。init_task dump 实证（scripts/dump_task_fields.py）：
    ```
    +0x778: init_cred   (real_cred)
    +0x780: init_cred   (cred)
    +0x788: 0x0000000000000000   ← 未知 8 字节字段，初值 0
    +0x790: "swapper\0"          ← comm[16] 在这里
    ```
    （upstream 5.10 cred 后直接是 comm；MTK vendor 在 cred 与 comm 之间插了一个 8 字节字段。）
  - `find_offset_access.py 0x788` 全内核 FUNC 扫描：**无任何函数直接访问 0x788**。
  - 所以运行时 `*(task+0x788) = 0 ≠ node` → **ne** → 写 `*(task+0x780) = word1 = init_cred`。
- **指令级上 C 与 R 的执行流逐条同构，差别仅是 parent 平移 8。C 没有任何不写 0x780 的分支理由。**
- 但实测 0/N（含 fork 模式 Cfork 全 6 发、external C1 51ms 即全风暴）。**矛盾。**

## 五、GhostLock 原始 W2 几何对照（几何本身可行）

`ghostlock_src/ghostlock-oneplus-main/src/core/util.c`（Write 2 cred）：

```c
fake_parent = pselect_custom_target - 8;          // pc = 写目标-8
fake_right  = data_addr(g_init_cred_image);       // word1 = init_cred
fake_left   = 0;
```

`main.c:586: do_one_write(child_task + TASK_CRED_OFF, "W2: cred", 2)` → 6.12 上
pc = &real_cred 字段（0x8F8），写 cred（0x900）——**与 matisse C-stage 完全同构**，
且原始 exploit 在 OnePlus 6.12 + FOPS 路由上成功（child uid==0 判定）。

**结论：change_child else 路径写 cred 的几何在原始 exploit 已被验证可行。
matisse C 失败是 5.10.209-MTK + SLIDE 路由特定的执行流问题，不是几何设计错误。**

## 六、新线索：Cfork child 在 10 秒内死亡

- child 心跳：轮询循环 `poll_i % 50 == 0`，200ms/次 → **每 10s 一行 `mt47: alive poll`**。
- Rfork2（成功轮）：child 存活，poll=50/100 风暴前、poll=150..400 风暴后（CapEff 满帽可见）。
- **Cfork（失败轮）：child pid=24355 打出 mt33 blocking 行后 0 心跳**——主进程日志持续到
  ~13.6s（>10s），child 应打出 poll=50 而没有 → **child 在 fork 后 ~10s 内死亡**。
- 所有实验脚本均**未收集 `/data/local/tmp/mt49_child_status.txt`**（child 每 200ms 写入的
  task/uid/euid/CapEff 快照 + fsync）——child 死前最后 200ms 的 cred 状态就在这个文件里，
  这是被忽略的决定性证据。**下轮实验必须收集。**
- 注意设备未崩溃（boot 仍 bf1c84d3）→ child 死亡不是整机 panic，更像 task 级
  SIGKILL/OOPS（do_exit）——与"erase 走了意外路径 → 杂散写打坏 child task"一致。

## 七、剩余假设（静态分析无法进一步区分）

- H1：C 轮 erase 的 node word2 运行时非 0（页覆写错位/风暴重排）→ successor/rebalance
  路径 → 旋转杂散写 → child 被杀、cred 不落。
- H2：C 轮 erase 触发链在 remove_waiter 之前走了不同分支（RB_EMPTY_NODE / 链路时序），
  erase 根本没执行到 CASE_A。
- H3：erase 执行且写中 0x780，但同轮 6 发风暴的后续内核路径（requeue/insert）又把 cred
  覆盖回原值或写坏 child。

## 八、E4：pi_tree 备用几何（绕开 __rb_change_child 分支悖论）

不依赖主树 change_child 的 left/right 分支判断，改用 **pi_tree erase 的 child 继承色写**：

```
PI_PC   (word3) = init_cred 别名     ← 写值
PI_RIGHT(word4) = task+0x780         ← 写目标 = cred 槽
PI_LEFT (word5) = 0
```

rb_erase(pi_node) CASE_A 指令流推演：

```
x8 = word4 = task+0x780 (child≠0 → 无 rebalance)
parent = word3 & ~3 = init_cred 别名
检查 *(init_cred+0x10) == node?   ; euid/egid 区 = 0 ≠ node → ne
STORE(a): *(init_cred+8) = task+0x780   ; gid/suid 区污染，无特权语义，无害
STORE(b): *(task+0x780) = word3          ; ★ cred = init_cred —— 目标达成 ★
```

- 主树必须无害化：TREE_PC=fake_lock（喷页零区）、TREE_RIGHT=0、TREE_LEFT=0
  → CASE_A child=0 → 只写 `*(fake_lock+8)=0`（零区自写，无害）。
- child≠0 无 rebalance 实证（cbz x8 / mov x10,xzr）→ 无旋转杂散写。
- pi erase 触发链与主 erase 同链（remove_waiter/adjust_prio_chain 都会走到
  rt_mutex_dequeue_pi；现行 PI_*=0 时每轮也都在执行，只是走 root 路径清
  `[current+0x880]`，无崩溃——触发已被隐式验证）。
- **两轮策略（两进程，一进程一写——crash#2 教训同进程 RETRY=1）：**
  R（主树写 real_cred，fork 进程）→ E4（pi 树写 cred，external PSELECT_TASK=R 轮
  child）→ real==cred==init_cred 别名 → AND-gate 命中（CapEff 满 && euid==0）
  → setresuid(0) → root。
- 隔离用法（fork，无 PSELECT_TASK）：只写 cred → CapEff 空 && euid=0 半程态，
  STRICT AND-gate 结构性不触发 → 安全，判据 = status 文件 euid=0 且 CapEff=0。
- E4 若成功而 C 失败 → 问题精确定位在主树 erase 的分支选择/触发；若 E4 也失败 →
  问题在 erase 触发链上游（H2），转向只读取证。
- E4 相对 C1 的运维优势：mt51 发间中止用 C 语义（euid==0），**无需 mt64 的
  chmod 000 致盲**——状态文件全程可读，落地反馈干净。

## 九、下轮实验矩阵（mt72）

| 实验 | 配置 | 判据 | 回答 |
|---|---|---|---|
| E4a | fork + `PSELECT_PTR_PI=1`（无 TASK） | status `euid=0` 且 `CapEff=0` | pi 几何隔离可行性；绕开 C 悖论 |
| E4b | R fork 轮 → external `PSELECT_PTR_PI=1` + `PSELECT_TASK` | child euid=0 / ROOT-SEEN / root_alive | 两轮链全通 → root |
| E2 | 任意轮 + 每秒 `/proc/<child>/stat`+comm 快照 + 结束后拉取 `mt49_child_status.txt` | child 死亡时刻 + 死前 uid/euid | C 轮 cred 是否被写过又回滚（H3）；child 死因 |
| E1 | `PSELECT_PTR_PC_OFF` ∈ {0x770,0x778,0x788,0x790} 梯度（fork+STRICT） | 心跳 uid/CapEff/comm 变化分布 | 真实写落点测绘（0x788/0x790 写 comm 可观测） |
| GeomB 补跑 | R fork + PC_OFF=0x778 全风暴 | euid/uid 变化 | C 几何交叉确认（上次饿窗） |

## 十、本次产出工具

- `scripts/disasm.py` — ELF 符号/地址反汇编（size=0 推导 + skipdata）
- `scripts/find_offset_access.py` — 全 FUNC 扫描访问指定 task_struct 偏移的指令
- `scripts/dump_task_fields.py` — init_task 原始字节 dump（指针标注 + 符号锚点）
- `scripts/find_callers.py` — 调用者查找（分支目标解析）

## 十一、重建补记（2026-09-02）

- 沙盒重置丢失未提交工作，本文与 4 个分析脚本按 git 外备份内容重建；
  已提交部分（mt63-71、C 几何判定日志）从 gitee master @ 9e5fbd1 恢复。
- 重建时在 main.c E4 集成中发现并修复两处 bug：
  1. **PI 词清零 bug**：attempt 循环里 `PSELECT_PI_PC/RIGHT/LEFT` 被无条件
     setenv "0" —— E4 块设置的 PI 词当场被抹掉，pi erase 退化为全零 root 路径，
     E4 写静默失效。修复：`if (!getenv("PSELECT_PTR_PI"))` 守卫。
     （即：未修复版本跑 E4 实验 = 白跑，结论无效。）
  2. **mt51 阶段语义缺失**：PI 轮未设 `PSELECT_PTR_STAGE=C` → slide.c 默认 R 语义
     （CapEff 满即中止发次）→ external E4 轮（R 已落地、CapEff 已满）首发后误停，
     E4 静默变单发。修复：PI 块内显式 `setenv("PSELECT_PTR_STAGE", "C", 1)`。
- E4 轮次编排定为**两进程**（R fork 进程 → E4 external 进程），不做同进程 ALT：
  crash#2 教训（slide_reset_trigger_state 不清 v37_* 静态词，同进程第二次触发在
  已中毒 waiter 树上 rebalance → 旋转杂散写 → panic），一进程一写。
