# CVE-2026-43499 (GhostLock) 利用项目完整梳理

> 生成时间: 2026-07-16
> 设备: Redmi K50 Pro (matisse) / HyperOS 2.0.6.0.ULKCNXM / MTK 5.10.209

---

## 一、设备和环境

| 项目 | 值 |
|------|-----|
| 设备 | Redmi K50 Pro (matisse) |
| 系统 | HyperOS 2.0.6.0.ULKCNXM (Android 14, API 34) |
| 内核 | Linux 5.10.209 (MTK aarch64) |
| KASLR | **0**（未开启，已硬编码绕过） |
| SELinux | Enforcing |
| 开发环境 | Termux (clang 21.1.8) + Shizuku (rish, uid=2000 shell) |
| 编译 | `make PROJECT=matisse-OS2.0.6.0.ULKCNXM API=34 CC=clang` |
| 运行方式 | Shizuku rish 内 `LD_PRELOAD=/data/local/tmp/preload.so sleep 10` |

---

## 二、漏洞原理简介

CVE-2026-43499 是 Linux 内核 `rtmutex` 子系统的一个 Bug（`kernel/locking/rtmutex.c` 中的 `remove_waiter()`）：

1. `FUTEX_CMP_REQUEUE_PI` 检测到死锁（EDEADLK）时，chain walk 提前返回但**没有清理 W 的 `pi_blocked_on`**
2. W 的 `pi_blocked_on` 仍然指向 W 内核栈上的 `rt_mutex_waiter` 局部变量
3. W 的 `FUTEX_WAIT_REQUEUE_PI` 超时后，内核栈帧被释放
4. 之后任何跟随 `W->pi_blocked_on` 的 PI chain walk 都会对**已释放的内核栈内存**做 UAF
5. 如果在释放的栈上喷入受控数据（假 `rt_mutex_waiter` 结构），PI chain walk 中的 `rb_erase` 调用就可能向攻击者选定的内核地址写入数据

**最终目标**：覆写 ashmem 设备的 `miscdevice.fops` 指针为假 `file_operations`，再通过 `/dev/ashmem` 的 ioctl/mmap 实现任意内核读写 → 修改进程 cred → 关闭 SELinux → 提权到 root。

---

## 三、整体探索路线图

```
路线1: v系列 (v1-v36) — deep PI chain + pselect GhostLock rb_erase → FOPS覆写
       结果: ❌ 死路。rb_erase csel永远写parent+8(name_ptr),永远碰不到parent+16(fops)

路线2: R系列 (R1-R11) — GhostLock shape=1 直写 per-CPU delta → cred覆写
       结果: ❌ 关闭。bruteforce成功过(R8_test4)，但fake_task导致panic；shape=0读percpu必崩

路线3: trigger_stamp (v37) — EDEADLK UAF + 栈喷假waiter → PI chain walk读受控数据
       结果: 🔄 进行中。NULL task测试确认数据位置正确(手机重启)，
             已编译 init_task 版本，待测试
```

---

## 四、三条路线详细经过

### 4.1 路线1 — v 系列 (v1-v36): deep PI chain + pselect GhostLock

**核心机制**：创建一个"deep PI chain"（block_holder → owner → waiter 三层 PI 链），waiter 真正阻塞在 `FUTEX_LOCK_PI` 上，pselect_thread 在 waiter 阻塞期间跑 GhostLock 竞态攻击。内核在合法 PI 链上下文中处理损坏数据，架构稳定不崩（v30/v34/v35/v36 共 6 次测试从未崩溃）。

**关键测试数据**：

| 版本 | parent | target | ret | calls | rb_erase执行? | 手机 |
|------|--------|--------|-----|-------|--------------|------|
| v30 | OFF\|RED | name_ptr | **193** | 1/1 | ✅→写name_ptr | 正常 |
| v34 | selinux-8\|RED | selinux | 72 | 1/1 | ❌ | 正常 |
| v35 | FOPS-8\|RED | FOPS | 1 | 1/1 | ❌ | 正常 |
| v36 | bootid-8\|RED | bootid_data | 1 | 1/1 | ❌ | 正常 |

**关键发现**：

- **OFF (0xffffff80028e76d8)** 是唯一确认能触发 rb_erase 的 parent 值
- FOPS-8 = OFF+0x08，仅距 OFF 8字节 → 仍不触发 rb_erase
- rb_erase csel 检查 `parent->rb_left == node`，永远失败 → 写 `parent->rb_right` = `parent+0x08` = name_ptr，永远碰不到 `parent+0x10` = fops
- parent 同时决定"能否触发"和"写到哪里"，这两个属性不可解耦
- **结论：FOPS 覆写路线死路** ✅

**留存资产**：deep PI chain 稳定架构 + shape=1 框架 + 正确的 word 映射 + canon_addr 修复

---

### 4.2 路线2 — R 系列 (R1-R11): GhostLock shape=1 直写

**核心机制**：放弃 FOPS 覆写/configfs 路线，直接用 GhostLock 写原语覆写当前进程的 cred 指针为 init_cred，一步到位提权。需要先通过 shape=0 读原语泄露 per-CPU delta 来定位当前 task。

**架构演进**：

| 版本 | 改动 | 结果 |
|------|------|------|
| R1-R7 | MM_STRUCT_SZ 错误(0x500→0x3C0) / 部署问题 / slab耗尽 | bruteforce 全部失败 |
| **R8** | MM_STRUCT_SZ=0x3C0, KASLR=0, cooldown 5s | **★ test4: bruteforce 首次成功, GhostLock 触发** |
| R8_test4 | rish, uid=2000 shell | phase6 leaked=ffffff80734be180 ★ 首次! GhostLock写触发成功, pselect期间 kernel panic |
| R9 | 父进程直接 prepare | panic 更快 |
| R10 | Page Holder 分离(fork子进程 prepare) | 未部署 |
| R11 | fflush/超时/DIRECT_PCPU_DELTA/FOPS reprepare | 已部署, 待测试 |

**R8_test4 关键日志**：
```
direct-w64[0] target=ffffff80028a77d0 value=ffffffc00a78a590 shape=0 workspace=ffffff80734b8000
```
- rb_erase 确实被执行，写操作确实发生
- 但 pselect 期间 kernel panic → 重启

**R8_test4 panic 根因**（已定位）：

对比 fops.c (R系列 main route) 和 slide.c (slide route) 的 pselect fd_set 编码：

```
字段          main route (CRASH)        slide route (OK)
─────────────────────────────────────────────────────────
word[10] task FAKE_TASK (sprayed page)  SLIDE_INIT_TASK (real init_task)
word[11] lock fake_lock                 fake_lock
```

- 内核 PI chain walk 中访问 `waiter->task->priority`, `task->pi_waiters` 等字段
- 假 task_struct (sprayed page) 含无效指针 → kernel panic
- slide 路径用真正的 init_task → 所有字段有效 → 安全

**解决方法**（一行改动）：`fops.c` 中 `{10, fake_task, "task"}` → `{10, canon_addr(INIT_TASK), "task"}`

**R 系列为什么关闭**：

- shape=0 读原语（用于泄露 per-CPU delta）写入目标是 percpu_slot 区域 → 破坏 per-CPU 变量寻址 → 立即 kernel panic
- shape=1 写原语需要先知道 per-CPU delta，但获取 delta 的唯一方法（shape=0 读）本身就会崩
- v 系列 shape=0 不崩是因为写入目标是 miscdevice 的 name_ptr → 只影响设备名显示 → 无害
- **教训：永远不要用 GhostLock 写 per-CPU offset 表或任何关键内核数据结构**

**从 R 系列继承到后续路线的资产**：

- Page Holder 分离方案（fork 子进程 prepare，pipe 传回地址）
- fflush 纪律（所有关键路径前强制 fflush(stdout)，防止 pipe 缓冲在 panic 时丢失）
- 部署验证铁律（cp 后 sha256sum 对比，Shizuku cp 曾写全零文件）
- MTK slab 脆弱性认知（每次重启后最多 2 次测试）
- INIT_TASK 安全替代 fake_task
- MM_STRUCT_SZ = 0x3C0, prepare = 272

---

### 4.3 路线3 — trigger_stamp (v37): EDEADLK UAF + 受控 stamp

**为什么要走这条路**：

v35/v36 确认 deep chain + pselect GhostLock 路线中 FOPS 覆写不可行；R 系列 shape=0 读原语太危险。回头审视 CVE 仓库自带的原始 `trigger.c` PoC — 它用 EDEADLK + stack UAF 而不是 deep PI chain + pselect。

**原始 trigger.c 验证**（trigger_edeadlk_test5）：

```
FUTEX_CMP_REQUEUE_PI → errno=35 (EDEADLK) ✅
FUTEX_WAIT_REQUEUE_PI → errno=110 (ETIMEDOUT, 栈释放) ✅
FUTEX_LOCK_PI(cycle_futex) → PI chain walk → UAF → returned! ✅
手机没崩 ✅
```

证明 EDEADLK + stack UAF 这条路在 matisse 上走得通，不依赖 pselect。

**trigger_stamp.c 改造**：

把原始 trigger.c 中 `for(i=0;i<200;i++) getpid()` 的栈搅动，替换为**受控数据喷入**：

- `setsockopt(AF_INET6, IPPROTO_IPV6, MCAST_JOIN_SOURCE_GROUP, buf, 512)` — 通过 socket 将 `buf[64]`（512 字节）喷入释放后的内核栈
- `pipe/write(buf, 512)` — 双保险
- `buf[0..5]` = 假 rb_node（tree_entry + pi_tree_entry，parent=OFF|RED，左右子节点受控）
- `buf[6]` = 假 task 指针
- `buf[7]` = 假 lock = 0xBEEF000000000000
- `buf[8]` = prio = 120|(139<<16)
- `buf[9..63]` = 0xDEAD+i 填充

**trigger_stamp test1**：

```
FCRQ ret=-1 errno=35 (EDEADLK)        ✅
FWRQ ret=-1 errno=110 (超时, 栈释放)    ✅
UAF probe: FUTEX_LOCK_PI(cycle_futex)
UAF probe returned!                     ✅  PI chain walk 没崩
```

**但不确定 stamp 数据是否真的落在了正确偏移。**

**trigger_stamp NULL task 验证**：把 buf[6] 改为 0（task=NULL）

- 设计意图：如果 PI chain walk 读到 stamp → 解引用 NULL → 必然 kernel panic。崩 = stamp 位置正确
- **结果：手机直接重启**（只有 "Server is not running" 22 字节落盘）
- **结论：✅ stamp 数据确实在正确偏移被 PI chain walk 读到了**

---

## 五、rt_mutex_waiter 结构布局

```
offset  field
+0x00:  tree_entry.__rb_parent_color   ← parent & RED flag → 决定 rb_erase 写哪里
+0x08:  tree_entry.rb_right            ← Path A 写入值
+0x10:  tree_entry.rb_left             ← NULL → 走 Path A (不走 successor 遍历)
+0x18:  pi_tree_entry.__rb_parent_color
+0x20:  pi_tree_entry.rb_right
+0x28:  pi_tree_entry.rb_left
+0x30:  task                            ← task_struct 指针
+0x38:  lock                            ← rt_mutex 指针
+0x40:  prio                            ← 优先级 (低32位)
```

**rb_erase 写入逻辑** (Path A, left=NULL, right≠NULL):

```
child = node->rb_right
if parent->rb_left == node:
    parent->rb_left = child     ← 写到 parent+0x10 (fops所在偏移!)
else:
    parent->rb_right = child    ← 写到 parent+0x08 (name_ptr)
```

csel 选择 `parent->rb_left == node` 需要 parent 的 rb_left 字段恰好等于 node 的栈地址，在实战中几乎永远为 false → 永远走 else → 写 parent+0x08。

---

## 六、关键地址速查（kallsyms 验证）

```
KIMAGE_TEXT_BASE:     0xffffffc008000000
P0_PAGE_OFFSET:       0xffffff8000000000  (direct map 基址)
P0_PHYS_OFFSET:       0x80000000
P0_KERNEL_PHYS_DELTA: 0

init_task (text):     0xffffffc00a79bec0
init_task (dmap):     0xffffff800279bec0
ASHMEM_MISC_OFF:      0xffffff80028e76d8   (OFF — 唯一能触发rb_erase的parent)
ASHMEM_MISC_FOPS:     0xffffff80028e76e8   (OFF+0x10 — 真正的覆写目标)
FOPS-8:               0xffffff80028e76e0   (OFF+0x08 — 距OFF仅8字节,不触发)
bootid_data:          0xffffff80028a77d0
SELINUX_ENFORCING:    KIMAGE_TEXT_BASE + 0x2a41b99
INIT_TASK_OFF:        0x279BEC0
```

---

## 七、已知死胡同

| # | 方案 | 失败原因 |
|---|------|---------|
| 1 | sprayed page 假树 (v17/v19/v20) | 三次失败，内核不认喷的页上的地址为有效 rb_node parent |
| 2 | tree_pc = FOPS-8 (v22/v23_t2/v25_pi) | ret=0，不触发 GhostLock |
| 3 | tree_pc = FOPS (v23_03) | ret=1，触发但不写 fops |
| 4 | tree_left=0 && tree_right=0 (v23_10) | 全零子节点 → `__rb_erase_color` → kernel panic |
| 5 | configfs_write 直接写 | errno=22 (EINVAL)，必须先覆写 fops |
| 6 | /proc/misc 验证 (v26) | SELinux EACCES |
| 7 | v35 FOPS-8 shape=1 直写 | parent 距 OFF 仅 8 字节仍不触发 |
| 8 | R 系列 shape=0 读原语 | 写 0 到 per-CPU offset 表 → 立即 panic |
| 9 | fake_task (R8) | PI chain walk 解引用假 task_struct 无效字段 → panic |

---

## 八、当前卡点 & 待解决问题

1. **rb_erase parent 的双重属性无法解耦**：parent 同时决定"能否触发 rb_erase"和"写到哪里"。唯一确认能触发的 parent=OFF，写入目标是 OFF+0x08=name_ptr（无害），而不是 OFF+0x10=fops（真正的目标）。差距仅 8 字节，但 rb-tree 遍历逻辑无法绕过。

2. **EDEADLK stamp 路径中 lock 字段**：stamp 里的 lock=0xBEEF000000000000（假值），PI chain walk 中会做 `waiter->lock == expected_lock` 校验，不匹配就直接 return → **rb_erase 永远不会被调用**。要触发 rb_erase，lock 必须指向真实锁地址且匹配当前 PI chain 上下文。

3. **stamp 喷入精度不可控**：socket+pipe 喷栈是 spray-and-pray，数据落点有随机性。虽然有 NULL task 测试验证了 stamp 能落到正确偏移，但无法保证每次都在精确的字节偏移。

4. **MTK 内核 slab 脆弱**：每次重启后最多跑 2 次测试，第 3 次大概率 slab 耗尽→kernel panic。每轮测试间隔必须给内核 GC 时间。

5. **Termux 弹退风险**：Termux 极易闪退，源码必须放在项目目录（不能放 /tmp），测试前后必须更新 CHECKPOINT 并保存日志。

---

## 九、下一步可尝试的方向

1. **EDEADLK stamp + rb_erase 触发**：修复 stamp 中的 lock 字段为真实锁地址，让 PI chain walk 的锁校验通过，从而走到 rb_erase，观察偏移和写入行为
2. **Path C (tree_left≠0 && tree_right≠0)**：让 rb_erase 走 successor 遍历路径，可能有额外的颜色修正写入偏移可以命中 fops。高风险（v23_10 已崩），但可能绕过 Path A 的 csel 限制
3. **修改 waiter.lock 字段匹配真实锁**：pi_tree 路径的 lock 回指验证需要 `waiter->lock == lock`，改成真实锁地址可能通过验证
4. **v+R 混合路线**：用 R 系列 shape=1 写原语 + init_task 修复，只写 FOPS 一个地址（不需要 per-CPU delta），然后用 configfs 做后续内核 R/W

---

## 十、项目文件结构速查

```
matisse_backup_essentials/
├── !!!_AI_READ_THIS_FIRST.md          ★ 完整项目上下文 + 当前状态 + TERMUX警告
├── !!!_LESSONS_LEARNED.md             ★ 经验教训 + 死路清单 + 历史Bug
├── !!!_RESUME_GUIDE.md                重启后恢复流程指南
├── 工作概览_恢复指南.md               中文版工作概览
├── 操作指南.md / 项目恢复指南.md       中文版操作指南
├── CHECKPOINT_*.md (30+ 份)           各版本分析断点 (v28→v37, R1→R11)
├── AI_ARCHIVE_*.md (4 份)             AI会话结束时留档的状态快照
├── MT论坛求助_项目完整梳理.md          本文件
├── preload_mtk_R1~R11.so (11 个)      R系列编译产物 (~107-111KB)
├── preload_mtk_v31~v36.so (6 个)      v系列后期编译产物 (105-164KB)
├── bin_v_archive/                     v系列旧二进制存档
├── CyberMeowfia/IonStack/.../         主源码 (popsicle fork)
├── fusion_release/src/                独立R系列源码 (含Makefile/CHANGELOG)
├── CVE-2026-43499_ref/                CVE公开资料 + trigger.c + trigger_stamp.c
├── ref/                               反汇编/符号表/ELF/target.h
├── images/                            boot/kernel 镜像
├── scripts/                           40+ Python分析脚本
├── logs/                              80+ 份测试日志
└── trigger_test                       trigger.c 编译产物
```

---

*以上基于项目目录所有 CHECKPOINT、AI_ARCHIVE、日志、源码整理。*

*最后更新: 2026-07-16*
