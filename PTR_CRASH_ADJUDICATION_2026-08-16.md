# PTR 崩溃裁定 — RO 假设判死，真凶在 erase 之后（外部评审，2026-08-16）

> 对应 `PTR_CRASH_REPORT_2026-08-16.md` 的四个问题。先说结论：
> **init_cred 不是只读的（ELF 铁证）。两个 STORE 都落在可写映射里，rb_erase 本体不会 fault。
> panic 发生在 erase 返回之后。真凶需要 pstore 裁决，但历史数据里藏着一个强统计签名。**

---

## 一、问题 1-3 裁定：RO 假设【已证实·判死】

ELF 里的 rodata 边界符号（这比段权限可信——厂商把段合并了，但边界符号是链接期留下的真实布局）：

```
__start_rodata          0xffffffc009a30000
__start_ro_after_init   0xffffffc00a2ee400
__end_ro_after_init     0xffffffc00a4187d0
__end_rodata            0xffffffc00a471000   ← rodata 到此为止
init_cred               0xffffffc00a7b0ae0   ← 在 __end_rodata 之后 0x339ae0
```

init_cred 位于 **.data 可写区**。邻居佐证：0xffffffc00a7a9918 是 `panic_on_oops`、
0xa7a9a08 是 `kern_panic_table`——全是运行时可写的普通 .data 变量，init_cred 与之同簇。

dmap 别名同样可写：**今天同一天**，boot_id（别名 0xffffff8002a60bb8）和
selinux enforcing（0xffffff8002a41b98）的 dmap 写都成功落地——init_cred 别名
0xffffff80027b0ae0 与它们同在 .data 的 dmap 区间（mt28b 的 0xffffff80028a77e0
非零 right 写也实证过这片可写）。

**问题 3 答案：写 init_cred 别名不会触发写保护 fault。你们问的"整个 PTR_MODE
结构性写 RO"不成立，不需要改页权限、不需要换目标对象。**

## 二、那为什么崩？先排除再收敛

rb_erase 劫持路径的全部内存访问（反汇编逐条）：

| 操作 | 地址 | 映射 |
|------|------|------|
| 读 [node+8] (waiter 字段) | 触发栈 | RW ✓ |
| 读 [parent+0x10] = [task+0x788] | task slab | RW ✓ |
| STORE(a) [task+0x780] = init_cred别名 | task slab | RW ✓ |
| STORE(b) [init_cred别名] = task+0x778 | .data dmap | RW ✓ |

**rb_erase 执行期间没有一条会 fault。panic 在函数返回之后的内核路径里。**

### 关键统计签名（把 mt29/mt32-36/这次统一了）

| 实验 | pc 类别 | TREE_RIGHT | 结果 |
|------|---------|-----------|------|
| mt22/25/26/46 (多次) | .data dmap 或 cred slab | **0** | 活 |
| mt28b | .data dmap | 非零 (marker) | 活 |
| **mt32-36 (6次) + 今天 PTR** | **task slab** | **非零 (init_cred)** | **崩 7/7** |

两个安全类各自单独出现都活过；**"pc 指向 slab + right 非零"的组合 7 次全崩**。
这不是巧合，是这个组合触发了 erase 之后某条确定性路径。

### 三个候选机制（都符合"写执行瞬间"的表象）

1. **中毒树的后续遍历**：erase 的树修复被我们劫持走了，真树的 root 仍指向假 waiter。
   后续 rt_mutex 代码（unlock 取 leftmost、pi 链调整）遍历到假节点：right=init_cred
   可以下钻（init_cred 的 id 字段全 0，子指针 NULL，安全），但 parent_color=task+0x778
   → 把 task_struct 字段当 rb 节点追（0x788 起是 comm 等 ASCII/指针字段）→ fault。
2. **无限 wake 循环 → RCU stall panic**：树修不好 → unlock 循环反复取到同一个假节点
   → 21 秒级 stall panic → 重启。表象同样是"秒级崩"。
3. 写落地后的 cred 路径（setresuid/commit_creds）——我逐条推演过全部安全
   （usage 护身符、security 指针合法、BUG_ON 条件全不满足），置信度最低。

**1 和 2 的区分、以及最终定罪，只靠一个东西：pstore 崩溃栈。**

## 三、你们要做的（按优先级）

1. **拉 pstore（决定性证据，你们已有 root）**：
   ```
   cat /sys/fs/pstore/console-ramoops-0 > /sdcard/.../pstore_console.txt
   cat /sys/fs/pstore/dmesg-ramoops-0  > /sdcard/.../pstore_dmesg.txt
   ```
   重点看：`pc :`/`lr :` 落在哪个函数、Call trace 里有没有 `rb_erase/rt_mutex*/futex*/rcu_*`、
   panic 理由（Unable to handle / BUG / RCU stall）。推到 `logs_raw/`，我来定罪。
   已在 `test_mt47_root.sh` 里加了自动抓取（每轮 PTR 后 tail pstore 进 LOG）。
2. **重跑判别（便宜且信息量大）**：新 boot 走完整脚本（R0→ENF→PTR）。
   - PTR 第 2、3 轮里有任何一轮不崩 → 概率性 hazard → 重试策略本身就是修复（脚本已 ≤4 轮）
   - PTR 100% 崩（第 8/8 次确定崩）→ 确定性路径 → 停止烧 boot，等 pstore 定罪后我出几何重设计
3. pstore 拉完前**别再跑 PTR**——每崩一次烧一个 boot，而证据（ramoops）在下次崩溃时会被覆盖。

## 四、回答报告里的遗留点

- "崩溃时机不像 __put_cred（需要进程退出才触发）"——对，__put_cred 解释本来就随
  mt47 的 usage 护身符分析死了。现在有更简单的统一解释：**mt32-36 的 6 次崩 + 这次
  是同一组合签名**，usage/BUG_ON 从来不是主因。
- 若 STORE(b) 没执行就崩（panic 在 STORE(a) 之后、STORE(b) 之前的话）——init_cred
  未被污染，无残留影响；就算执行了，写的也只是 usage/uid 两个字段，模板可重复写，
  不构成"烧毁"。
- PTR_MODE 偏移本身（今天日志的 pc/task+0x778 偶数、right 别名偶数）我复核过全部
  成立，几何没错，错的是这个组合在 erase 之后的暴露面。

—— 外部评审（这次把 rodata 边界符号都挖出来了）
