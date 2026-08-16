# TASK_ASSIGNMENT 三项裁定（外部评审答复，2026-08-16）

> 对应你们的 `TASK_ASSIGNMENT_2026-08-16.md`。格式按你们要求：每项给结论+证据，
> 标注【已证实】(反汇编铁证) /【推断】(无直接证据) /【未知】。
> 所有地址来自 `ref/kernel_with_symbols.elf` 实际反汇编，脚本 `analyze12~15.py` 可复跑。

---

## 任务 1：EACCES 真实来源 + 四个修复方向裁定

### 1.0 先纠正两个你们动态诊断里的误读【已证实】

**误读 1：`cat /proc/$CPID/mem` rc=1 ≠ open 被拒。**
cat 从偏移 0 读，地址 0 未映射 → 读错误 EIO → rc=1。**open 成功也会是这个结果**。
你们的证据 #2 不能区分"open 拒绝"和"读错误"。判别命令应该是：
`dd if=/proc/$CPID/mem bs=1 count=1 2>&1` — 报 `Permission denied` 才是 open 被拒，
报 `Input/output error` 是 open 成功。已写入 `scripts/diag_eacces_60s.sh`。

**误读 2：SYSCHK 不会让进程退出。**
`kernelsnitch/utils.h:39-44`：SYSCHK 只 `pr_error` 然后返回 -1。
所以失败后进程继续跑（这解释了 rc=0——sleep 跑满 70s 正常退出），
`memfd_leak=-1`、`close(-1)` 是 EBADF 空操作，**pin 副作用静默丢失**，
prepare 后续在错误的 slab 假设上继续 → 触发落空 → boot_id 不变。
你们"pin 丢失 → 时序错乱"的机制推断是对的，但"进程崩了"不对，它活着，只是残废。

### 1.1 EACCES 的完整来源链【已证实，逐条有地址】

```
open(/proc/<pid>/mem)
 └ mem_open @0xffffffc00865ee00: mov w1,#2        ← mode=2 = PTRACE_MODE_ATTACH
   └ proc_mem_open @0xffffffc008658f30: orr w1,w19,#8  ← |=8 FSCREDS → mode=0xA
     └ mm_access @0xffffffc008129bd8:
         x21 = [task+0x518] (task->mm, get_task_mm 内联)
         cbz x21 → 跳过检查直接返回 NULL            ← ★ mm==NULL 时绝不 EACCES
         mm==current->mm → 跳过检查
         bl ptrace_may_access(0xA)
         失败 → bl mmput; mov x21,#-0xd            ← 唯一 EACCES 产生点
```

`__ptrace_may_access` @0xffffffc008148b50 检查链（按序）：

| # | 检查 | 地址 | 同 uid fork 子进程的结果 |
|---|------|------|--------------------------|
| 1 | FSCREDS/REALCREDS 必须有 | b74-b94 | 0xA 有 FSCREDS ✓ |
| 2 | task->signal == current->signal | ba0-bb0 | fork 子进程不同 signal → 不适用 |
| 3 | uid 交叉比对（caller uid/euid/suid/fsuid vs 目标全套） | bfc-c3c | 同 uid fork 全过 ✓ |
| 4 | 不过则查 CAP_SYS_PTRACE(0x13) 于目标 user_ns | c40-c90 | shell 无此 cap → 走到这里就拒 |
| 5 | dumpable: mm->flags&3 != 1 且无 CAP_SYS_PTRACE → 拒 | d54-d68 | 子进程 dumpable=1 时过 |
| 6 | security_ptrace_access_check → SELinux | e78/e84 起 | **PROCESS__PTRACE（ATTACH 级）** |

SELinux 侧证据 @0xffffffc0088bce4c：目标 SID 读 `child->real_cred@0x778`，
发起者 SID 读 `current->cred@0x780`，mode=0xA 无 READ 位 → 走 **PROCESS__PTRACE**。
注意：目录可见（你们证据 #1）只证明 PROCESS__READ 过了——**mem 打开查的是更高一级的
ptrace 权限**，两者是不同的策略权限，一个过不代表另一个过。

### 1.2 三个关键裁决

**裁决一：zombie 假设作为 EACCES 解释——判死【已证实】。**
子进程退出后 task->mm=NULL → mm_access 里 `cbz x21` 直接跳过整个检查块 →
返回 NULL → mem_open 里 IS_ERR(NULL)=false → **open 成功**（返回 fd，private_data=NULL）。
zombie 的 mem 永远不会 EACCES。你们任务单问题 3 的答案是：**不是必然 EACCES，是必然不 EACCES**。
（但 zombie 时 open 拿到的 fd 不 pin 任何 mm → "pin 静默丢失"这条你们说对了，
这是独立于 EACCES 的另一个真问题，见 1.3 修复 c。）

**裁决二：EACCES 必然意味着"打开瞬间子进程活着（mm 非空）且检查 4/5/6 之一失败"【已证实】。**
同 uid fork + dumpable=1 的子进程，4 和 5 静态上都过——**所以失败只能落在 6（SELinux
PROCESS__PTRACE）或 5（子进程 mm dumpable 被置 0）**。而 dumpable 被置 0 的内核
途径是 commit_creds 里的 set_dumpable（0xffffffc00818514c 里 `str wzr,[x21,#0x98]`
附近逻辑）——即该进程发生过**成功的** id 变更。shell uid 2000 的进程 setresuid(0,0,0)
是 EPERM，永远失败、永远无副作用。

**裁决三：上午/下午差异，最可能根因是【启动器语境变了】——推断（高置信），60 秒可判别。**
上午成功 boot：同一份 .so、同一策略、Enforcing 下 memfd 全开成功 →
证明 shell 域 →shell 域的 PROCESS__PTRACE 是允许的。
下午两个 boot 失败 → 发起者大概率不在 shell 域。重启后 Shizuku 的拉起方式变了
（无线调试配对丢了，用 root 拉起？或者干脆从 Termux 跑的？）：
- Termux（untrusted_app）：应用域无 process ptrace → 全部 open 拒 → EACCES，100% 复现、逐字节一致，符合"两个 boot 同点同错"
- root 语境：有 CAP_SYS_PTRACE 反而全过，不产生 EACCES——所以如果判别结果是 root，则此假设排除，转查 5（dumpable）
  
**这正是"重启改变持久状态"的答案候选：不是内核状态变了，是你们拉起 exploit 的路径变了。**
判别：`scripts/diag_eacces_60s.sh`，在**与失败运行完全相同的入口**执行，对照文末判读表 A-D。
另外跑之前重建 .so——新 `open_memfd` 带埋点，失败时会打出 pid/errno/子进程域/父进程域/进程状态
五个证据（util.c mt47-diag），比 SYSCHK 的裸 %m 强得多。

### 1.3 四个修复方向逐一裁定

| 方向 | 裁定 | 理由 |
|------|------|------|
| a. open 前 waitpid 确认 alive | **不解决 EACCES，仅可留作诊断** | EACCES 来自活子进程的策略拒绝（1.2 裁决二）；zombie 根本不产生 EACCES（裁决一）。查活不解决策略问题 |
| b. 子进程 usleep(500ms) | **否决** | 同 a，治不了 EACCES；反而改 find_collisions 时序 → 喷射/碰撞窗口漂移，slab 时序风险全在没有收益。别动 |
| c. 换 pin 方式 | **方向正确，但具体做法要换** | 正确设计：leak 子进程**自己 open /proc/self/mem**（检查 2 的 same signal 捷径——自开无条件放行，不查 SELinux 不查 dumpable【已证实，ba0-bb0】），经 unix socket `SCM_RIGHTS` 把 fd 传给父进程。从出生就 pin，无竞争、无策略依赖。释放点（决定 slab 释放时序的 close）保持在原来的位置不动 → 时序语义不变。**建议但未实施**——它动时序敏感路径，等判别测试结果出来再上，别盲改 |
| d. 诊断埋点 | **已实施并推送** | 见 1.2 末。比"打印 errno"多抓了域和 pid——这是能一击定位的证据 |

**执行顺序建议：先跑 diag_eacces_60s.sh（60 秒、零风险、不动内核），再决定要不要上 c。**
如果是判读表 A（启动器语境），修法是"换回上午的启动方式"，一行代码都不用改。

---

## 任务 2：mt47 PTR 轮 finit_module 的 avc 预检

**结论：保持 mt47 现有顺序（ENF 全局 Permissive 在前），insmod 的 SELinux 检查按构造通过。不需要任何改动。**

| 检查 | 结论 | 证据级别 |
|------|------|----------|
| capable(CAP_SYS_MODULE) | **过**。init_cred 的 user_ns=&init_user_ns 且 cap_effective=0x1fffffffffffffff | 【已证实】cap_capable @0xffffffc008aced8 是纯位图+user_ns 链检查 + init_cred 实测 dump |
| CONFIG_MODULES | **在**。is_module_sig_enforced 存在且返回 0，签名不强制 | 【已证实】@0xffffffc0082aa294 |
| modules_disabled | 未知，设备 30 秒可查：`cat /proc/sys/kernel/modules_disabled` 应为 0 | 【未知】 |
| SELinux module_load 类检查 | **Permissive 下按构造放行**（avc 拒绝只记日志不返回错误）；Enforcing 下取决于策略文件，ELF 里无法裁定 | 【推断】+【未知】 |

补充三点：
1. SELinux 模块加载钩子（selinux_kernel_module_from_file 等）在这个 GKI 内核里是
   static 函数，**符号被裁剪**，ELF 里查不到——这部分我确实做不了静态裁定，明说。
2. 换 cred 后 current_sid() 读的是 cred@0x780 的 security → init_cred → **kernel SID**
   【已证实，selinux_ptrace_access_check 反汇编同款取法】。kernel→kernel 的
   module_load 在多数策略里是允许的，但别依赖它——ENF 在前就是保险。
3. mt47 子进程里那个 setenforce 探针（预期失败、纯诊断）现在有了新用途：**如果探针意外
   成功了**，说明 kernel SID 拥有 security 权限，那时甚至不需要 ENF 轮。看探针 errno 即可。

---

## 任务 3：PTR_MODE ELF 偏移复核

**结论：三条全过，PTR_MODE 几何完全正确，无需改动。可以上设备。**

| 检查项 | 结论 | 证据 |
|--------|------|------|
| real_cred/cred 偏移 | **0x778=real_cred，0x780=cred，target.h 正确** | 【已证实】commit_creds @0xffffffc00818514c 开头连续两条 load：`ldr x19,[x20,#0x778]`（old=real_cred）、`ldr x8,[x20,#0x780]`（cred）。与早前 getuid 反汇编独立互证 |
| pc=task+0x778 奇偶 | 偶 ✓。task 是 slab 对象 8 对齐，+0x778 仍 8 对齐。且 TREE_RIGHT=init_cred≠0 时 rebalance 整个被跳过（rb_erase @0xffffffc008a71228 反汇编），奇偶根本不参与判定 | 【已证实】 |
| init_cred 别名 dmap 偶偶 | 偶 ✓。镜像地址 0xffffffc00a7b0**ae0**，P0_KERNEL_PHYS_DELTA 是页对齐量，低 12 位保留 → 别名低位 0xae0，bit0=0 | 【已证实】（delta 页对齐这一点由 P0 别名换算公式保证，若你们想双保险，跑前打印一次别名值看末位即可） |
| STORE(b) 写值含 0 字节 | **不是问题**。ARM64 `str` 是定长 8 字节指针写，没有字符串截断语义。任务单里这条担心可以划掉 | 【已证实，指令语义】 |

写入链重放（对照代码确认无误）：
```
STORE(a): [(task+0x778)&~3 + 8] = init_cred别名  → [task+0x780]=cred字段 = init_cred ✓ 正确命中 cred
STORE(b): [init_cred别名] = pc(=task+0x778)      → usage←低32位(≈1.5e9 护身符), uid←0xffffff80(子进程 setresuid 自愈)
无 rebalance（child≠0）                            → 两个 store 全落合法可写内存 ✓
```

---

## 给现场的执行序（成本从零到低）

1. **60 秒**：在与失败完全相同的入口跑 `scripts/diag_eacces_60s.sh`，对照判读表 A-D。A → 换启动方式直接重跑 mt47；B/C/D → 把输出发我。
2. **顺手 30 秒**：`cat /proc/sys/kernel/modules_disabled`（任务 2 的唯一未知项）。
3. 重建 .so（含 mt47-diag 埋点）后再跑 mt47：如果 EACCES 复现，日志会直接吐出 pid/域/状态，不用再猜。
4. c 方案（SCM_RIGHTS 自开 pin）**先别上**——等 1 的结果定性后按需实施，我这边代码草案已备好。

—— 外部评审（这次带的是一整条反汇编出来的检查链）
