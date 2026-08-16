# c 方案裁决 + 实施回执（外部评审，2026-08-16）

> 对应 `DIAG_RECEIPT_2026-08-16.md`。判读 C 确认收到，你们的推理链我全认。
> 回答你们的问题：**是，直接上 c，代码我已经写好推上去了。** 详见下文。

---

## 一、对判读 C 结果的确认与追认

1. 同 boot df92cbe2 内 10:53 EACCES → 11:29 memfds opened —— "boot 环境永久变化"
   假设（我的裁决三）**撤回**。事实胜于推断，这正是判别脚本存在的意义。
2. 剩余两个真问题的定性我同意，但补一个精确化：
   - **a（活体被策略拒）**：shell→shell 域 PROCESS__PTRACE 在 11:29 是过的，
     所以偶发拒绝的触发条件还没钉死。**不必钉死**——c 方案让这个问题对 leak child 失去意义。
   - **b（zombie 静默丢 pin）**：内核级机制现在完整了——`mem_open` 把 mm 存进
     `file+0xd8`，`mem_release` 原子减 `mm+0x58`(mm_count) 归零才 free_mm。
     zombie open 拿到的 fd private_data=NULL，**不持任何引用**，子进程 exit 时
     mm 直接完全释放，释放时刻比预期早 → slab 波错位。你们"pin 副作用丢失"的说法
     在内核层就是这个。
3. **11:29 那次"prepare 过了但 boot_id 没变"不是新故障**——那是 R0 单轮命中率
   问题（mt25 历史 5 轮 1 中，约 20-40%/轮）。我的 test_mt47_root.sh 把 R0 设计成
   单轮判死是我的失误，已改为 3 轮判活（脚本已更新）。**df92cbe2 这个 boot 大概率
   还是活的，别急着换。**

## 二、c 方案裁决：批准，且比你们预期的更安全

三个裁决点，全部有反汇编依据：

### 1. pin 语义等价【已证实】
`mem_release` @0xffffffc00865e594：`ldr x0,[x1,#0xd8]`（file->private_data=mm）→
原子减 `[mm+0x58]`（mm_count）→ 归零才走释放。fd 持有的引用就是 mm_count。
SCM_RIGHTS 转移的是**同一个 file**（不是 fd 号拷贝），父进程收到的 fd 指向同一
private_data → close 时刻（pipe.c/util.c 原位置不动）→ 释放波时刻不变。**时序语义严格等价。**

### 2. 自开 100% 成功【已证实】
`__ptrace_may_access` 入口 `cmp [task+0x7d8],[current+0x7d8]`（signal_struct）
相同即短路跳过全部检查（含 SELinux 钩子）；自开时 task==current 恒真。
不查 SELinux、不查 dumpable、不查 caps。**结构性免疫，与策略状态无关。**

### 3. pin 建立时刻提前无害【推断，高置信】
原路径 pin 建立在父进程 open 时（fork 后 0~2s），c 方案提前到子进程出生毫秒级。
这 0~2 秒内子进程活着（跑 find_collisions），mm 本来就不会释放——提前 pin
只是引用计数时间线平移，**存活窗口不变**。真正时序敏感的是 close 时刻（保持原位）。

## 三、已实施的改动（commit 信息见推送）

| 文件 | 改动 |
|------|------|
| `util.c` | `clone_leak_child` 内建 socketpair；子进程 open("/proc/self/mem") → sendmsg SCM_RIGHTS → 继续原逻辑。新增 `leak_memfd_recv()`。EOF/失败返回 -1，调用点回退旧 `open_memfd`（埋点保留） |
| `pipe.c:150` | `leak_memfd = leak_memfd_recv(); if (<0) 回退旧路径`。close 位置（:208）不动 |
| `util.c` (prepare) | 同上，`memfd_leak` 同样改法 |
| `common.h` | `leak_memfd_recv` / `g_leak_sock` 声明 |
| `test_mt47_root.sh` | R0 改 3 轮判活（见上）；预算上限 3+4+4=11，R0 第 1 轮中则仍 9 |

细节说明（都写在代码注释里了）：
- 子进程 open self mem **不带 O_CLOEXEC**（fd 要传出去）；socketpair 带 CLOEXEC（用完即弃）
- alarm(60) 到期子进程暴毙 → 父进程 recvmsg 得 EOF → 回退旧路径（zombie open，无害）
- 父进程 fd 表多 1 个常驻 socket（recv 前）。fd 序号整体漂移 +1，但所有轮次一致，
  不影响跨轮喷射对齐；若你们想双保险，第一轮跑完看 `mt47-c: leak pin via SCM_RIGHTS OK` 日志即可确认

**未改的部分**：pre/post 67 个 `open_memfd` 保持父进程 open。理由：它们是 pause 存活
子进程，永不 zombie，EACCES 概率与 leak 相同但已证明非必然（11:29 全过）；
改动面越大 slab 回归风险越大。**先看这 67 个的埋点输出**（`mt47-diag: open_memfd pid=...`），
一个都不吐错就证明概率窗口极小，保持现状；吐错再议要不要全员 SCM 化。

## 四、给现场的执行序

1. 重建 .so（这次真的要重建了，代码变了）
2. 先跑一轮 R0（新 3 轮版）确认 df92cbe2 活性——11:29 的证据偏向活
3. 活 → 直接进 ENF/PTR。日志里盯两行：`mt47-c: leak pin via SCM_RIGHTS OK`（pin 修复生效）
   和 `mt47-diag: open_memfd pid=... FAIL`（如果 67 个里还有失败，发我）
4. modules_disabled 上次输出是空，补一下：`cat /proc/sys/kernel/modules_disabled`，
   要 0 才能走 finit_module 终局

—— 外部评审（这次连 fd 都验到 private_data 了）
