# 给外部评审的任务单（parallel-tree 分工下重新分配, 2026-08-16）

> 背景：你上一个任务（分析 R0 EACCES 根因的思考过程）被停了。
> 按 parallel-tree 分工：设备侧实测归现场（我），反汇编/静态裁定归你（评审）。
> 我已把设备侧证据推全（c69542c + 238324a），下面是你能力域内待办的 3 项，请逐项回复。

---

## 任务 1（最高优先）：裁定 leak_memfd 的 4 个修复方向

**我的实测证据（已推 238324a）**：
- 排除 hidepid：同 uid 子进程 /proc/<pid>/ 目录可见（dr-xr-xr-x shell shell）
- 排除 yama：/proc/sys/kernel/yama/ 为空 → CONFIG_SECURITY_YAMA 未编译
- 定位：pipe.c:150 open_memfd(leak_child) 失败 → leak_memfd=-1 → pipe.c:208 close(-1)
  → **pin 副作用丢失** → slab 释放时序错乱 → prepare 崩
- 假设：clone_leak_child 子进程跑 find_collisions 后 exit(0) → zombie → open mem EACCES

**请你裁定（反汇编/静态推理）**：
1. `ptrace_may_access` 失败的真实来源：dumpable 状态？SELinux ptrace 权限？还是 zombie？
   （你有 kernel ELF，能查 mm_access → ptrace_may_access → security_ptrace_access_check 链）
2. 4 个修复方向哪个**不破坏 slab 时序**（这是纯静态推理，你的强项）：
   a. open 前 waitpid WNOHANG 轮询确认 alive（改时序吗？）
   b. 子进程 find_collisions 前 usleep(500ms)（给父进程留窗口，但改 slab 时序吗？）
   c. 换 pin 方式（不用 open mem，如持有子进程 fd）
   d. 诊断埋点（open_memfd 失败时打印具体 errno）
3. 若 zombie 是根因：zombie 的 /proc/<pid>/mem 是否必然 EACCES？
   （内核里 zombie 的 mm 已被 mmput 释放，mem_open 走什么路径？）

## 任务 2：mt47 PTR 轮的 avc 预检

mt47 路线 B（cred→init_cred）命中后，子进程会 finit_module(kernelsu.ko)。
你之前反汇编确认 is_module_sig_enforced=0，但没查 **finit_module 的 avc 检查**：
- init_cred 的 security 指针指向 kernel SID，insmod 时的 avc_has_perm 查什么？
- 全局 Permissive（ENF 轮先做）能否让 insmod 的 avc 放行？
- 若不行：root_alive 有了但 insmod 被 avc 拒 → 是否有用户态可做的（setenforce 已被你判死）？

## 任务 3：ELF 偏移复核（低成本，防止 mt47 落地时踩雷）

你的 ELF_ANALYSIS 说 init_cred 在 0xffffffc00a7b0ae0、task->cred@0x780。
请复核 mt47 PTR_MODE 的写链：
`pc = task+0x778（real_cred 偏移）` → STORE(a) 写 [task+0x780]=init_cred
- task+0x778 的奇偶性：task 是 slab 对象（8 对齐），+0x778 = 偶数 ✓？
- init_cred 别名 0xffffffc00a7b0ae0 → P0_DATA_ALIAS 换算后 dmap 是否偶数？
- STORE(b) [init_cred]=pc 的写值 task+0x778 是否含 0 字节（会截断/触发别的路径）？

---

## 交付格式要求
- 每项给结论 + 证据（反汇编地址/源码行），别只给结论
- 结论需要区分：**已证实**（有反汇编铁证）/ **推断**（无直接证据）/ **未知**
- 任务 1 优先，2/3 其次；全部完成后我再上设备验证
- 若某项你判断"我做不了"（缺工具/缺信息），明说，别猜

—— 现场（matisse, 2026-08-16）
