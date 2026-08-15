# 📖 经验教训总结 — CVE-2026-43499 GhostLock matisse

> 写给后续的 AI 和自己：少走弯路，别重复踩坑。
> 最后更新: 2026-07-16 (R2 崩溃分析完成，手机已重启)

---

## ⚡ TL;DR 当前阻塞

**现象**: GhostLock type confusion 完全触发 (ret=150~161), 但 `misc_fops` 始终为 0.

**原因**: rb_erase csel 检查 `parent->rb_left == node` 永远失败 → 写入 `parent->rb_right` (=name_ptr/name[8..15]), 而 fops 在 `parent->rb_left` (=OFF+0x10). 差 8 字节.

**v27 尝试**: 分离 tree_entry 和 pi_tree_entry 的 parent.
  - tree_pc=OFF|RED (已知触发) → 走 tree_entry 路径
  - pi_parent=FOPS-8|RED (新) → 走 pi_tree_entry 路径, 写入目标=FOPS!

---

## ☠️ 死路清单 — 已验证不可行的方案

### 死路 1: sprayed page 假树 (v17, v19, v20 — 三次失败)
**结论**: 内核不认 sprayed page 上的地址为有效 rb_node parent. **不要再尝试.**

### 死路 2: tree_pc = FOPS-8 (v22, v23_t2, v25_pi)
**结论**: FOPS-8 在 tree_entry 路径不触发 rb_erase (ret=0). pi_tree 单独用 FOPS-8 也不触发 (v25_pi ret=0). 但 FOPS-8 + OFF 的**组合** (v27) 尚未测试.

### 死路 3: tree_pc = FOPS (v23_03)
**结论**: ret=1, 不触发.

### 死路 4: tree_left=0 && tree_right=0 (v23_10)
**结论**: 全零子节点 → child=NULL → __rb_erase_color 触发 → 内核 panic. **禁止.**

### 死路 5: configfs_write 直接写 (所有版本)
**结论**: errno=22 (EINVAL), 需要通过 GhostLock 先覆盖 fops.

### 死路 6: /proc/misc 验证 (v26)
**结论**: HyperOS SELinux 封锁 /proc/misc (EACCES), 无法验证 name_ptr 覆写.

### 死路 7: configfs_read_once 读回验证 (所有版本)
**重要发现 (v26 分析)!** configfs_read_once 在 fops 未被覆盖时走真实 ashmem 设备, 读的是共享内存 (永远=0). 所以所有 `post-pselect misc_fops=0, name_8_15=0` 的输出都是**无效验证**. 只有 fops 被成功覆盖后, configfs 才有内核读写能力.

---

## 🐛 历史 Bug 回顾

### Bug: stdout 被 dup2 吃掉 (v16, v17)
**症状**: 输出中出现 `true: write` / `sleep: write`.
**原因**: open_selected_fds 把 pipe 读端 dup2 到 fd=1 (stdout).
**修复**: 跳过 fd 0/1/2. v18+ 已修复.

### Bug: v23_10 系统重启
**原因**: tree_left=0 且 tree_right=0 (两者同时为空) → __rb_erase_color 触发.

### Bug: v26 首次运行重启
**原因**: v25 被反复测试 7+ 次, 每次 clone 543 个子进程, 内核 slab 耗尽. 重启手机后 v26 正常运行.

---

## 🔬 rb_erase 反汇编核心发现

```
rb_node 结构体:
  +0x00: __rb_parent_color
  +0x08: rb_right
  +0x10: rb_left

miscdevice 结构体:
  +0x00: minor (4B) + padding (4B)
  +0x08: name_ptr (8B)           ← rb_erase 写到这里!
  +0x10: fops (8B)               ← 真正的目标
  +0x18: list

rt_mutex_waiter 结构体:
  +0x00: tree_entry (rb_node)    ← word 0-2
  +0x18: pi_tree_entry (rb_node) ← word 3-5
```

Path A (left=NULL, right≠NULL):
```
child = node->rb_right
if parent->rb_left == node:
    parent->rb_left = child
else:
    parent->rb_right = child     ← 永远走这里 (fops != stack addr)
```

**三个 rb_erase 调用点**:
| # | 目标 | rb_node | 验证 |
|---|------|---------|------|
| 1 | lock->waiters | tree_entry | 自父检查 |
| 2 | pi_tree | tree_entry | lock回指 |
| 3 | pi_tree | pi_tree_entry | lock回指 |

---

## 💡 可能的突破方向

### 方向 1: split-parent (v27 - 当前) ★
用两个不同的 parent 分别走 tree_entry 和 pi_tree_entry 路径. FOPS-8 单独不触发, 但可能在 OFF 同时触发的情况下也触发 (状态依赖).

### 方向 2: Path C — __rb_erase_color 写入
tree_left≠0 且 tree_right≠0 → successor 遍历 → 颜色修正写入多个节点. 高风险 (v23_10 已崩), 但可能绕过 csel.

### 方向 3: 修改 waiter.lock 字段
pi_tree 路径的 lock 回指验证需要 `waiter->lock == lock`. 当前 lock 字段 = fake_lock (sprayed page 地址). 如果改成真实 lock 地址可能通过验证.

---

## 📋 版本测试数据速查

| 版本 | tree_pc | pi_parent | ret | misc_fops | 备注 |
|------|---------|-----------|-----|-----------|------|
| v23_11 | OFF\|RED | OFF\|RED | **161** | 0 | 最强触发 |
| v25_1 | OFF-0x10\|RED | OFF-0x10\|RED | 0 | 0 | 不触发! |
| v25_test1 | OFF\|RED | OFF\|RED | 155 | 0 | 强触发 |
| v25_pi | **0** | **FOPS-8\|RED** | **0** | 0 | pi单独不触发 |
| v26 | OFF\|RED | OFF\|RED | 155 | 0 | 新增/proc/misc(被封) |
| **v27** | **OFF\|RED** | **FOPS-8\|RED** | ? | ? | ★ split-parent |

---

## ⚙️ 环境常数

```
设备: Redmi K50 Pro (matisse)
系统: HyperOS 2.0.6.0.ULKCNXM (Android 14, API 34)
内核: Linux 5.10.209 (MTK, aarch64)
KASLR: 0
CONFIG_DEBUG_RT_MUTEXES: y

ASHMEM_MISC_OFF:  0xffffff80028e76d8  (direct map)
ASHMEM_MISC_FOPS: 0xffffff80028e76e8  (direct map)
FOPS-8:           0xffffff80028e76e0  (direct map)
ashmem_fops:      0xffffffc00a2acf58  (text)
init_task:        0xffffff800279bec0  (direct map)
init_task_comm:   0xffffffc00a79c6f0  (text, =init_task+KIMAGE_TEXT_BASE_delta+TASK_COMM_OFF)
```

---

## 🐛 R1 环境阻塞 (2026-07-15/16)

**问题1**: Termux 直接跑 → SELinux untrusted_app_27 禁 /proc/PID/mem → Permission denied

**问题2**: rish **挂载命名空间隔离**！rish shell 和 Termux 的 `/data/local/tmp/` 是不同目录
- Termux 部署 R1 到 /data/local/tmp/preload.so → rish 看不到
- rish 里有旧的 v 系列 preload.so → 一直在跑旧代码
- 解决: 用 `rish -c "rm ... && cp /sdcard/... ..."` 在 rish 内部署

**问题3**: rish 脚本的 dex 权限检查 (`[ -w $DEX ]`) 在部分文件系统上误判，会阻止执行
- 解决: 裸调 app_process 绕过，或用 /data/local/tmp/rish_shizuku.dex

**rish 正确用法**: `RISH_APPLICATION_ID=com.termux /system/bin/app_process -Djava.class.path=/data/local/tmp/rish_shizuku.dex /system/bin --nice-name=rish rikka.shizuku.shell.ShizukuShellLoader -c "命令"`

**问题4 (★ R1 关键发现)**: 源码和编译出的 .so 不对应！
- 当前 main.c 是 `run_direct_root_stage()` (direct cred write)
- 编译出的 preload_mtk_R1.so 跑的却是 v30 的 FOPS 老路
- 症状: 测试输出出现 `FOPS stage starting` / `try_cfi_stage`，而不是 `direct mode=init_cred`
- 教训: 编译后必须 `make clean` 再 `make`，且用 `strings preload.so | grep -E 'direct mode|FOPS stage'` 验证输出包含正确的阶段日志

---

## 🚨 R2 崩溃教训 (2026-07-16) ★ NEW

### Bug: R1 和 R2 是同一个文件！
**症状**: R2_test1 只输出 5 行就重启，和 R1_test4 行为一致。
**原因**: R2 从何而来？打开日志一看，R1.so 和 R2.so 的 SHA256 完全一致 (017fb8a6...)。根本没有 `make clean && make`，只是把同一个文件复制改名了。
**教训**:
- **编译后必须先验证 SHA256！** — `make` 之后立刻 `sha256sum`，确认和旧版不同
- **验证二进制内容** — `strings preload.so | grep 'direct mode'` 确认包含正确的代码路径
- **别以为改了文件名就是新版本** — 名号是给人看的，内核只看字节

### Bug: 连续测试导致 slab 耗尽重启
**症状**: R1_test4 跑 20s 重启 (0 字节输出)，R2_test1 跑 1m59s 重启 (仅 5 行输出)。
**根因**: `prepare_good_kernel_page()` 每次都 clone 500+ 子进程、做 heap spray (pipe+memfd)、SKB reclaim。MTK 5.10 内核 slab 扛不住连续跑。
- R1_test1→test2→test3→test4 连续跑 → test4 崩
- 手机重启后 R2_test1 立刻跑 → 又崩

**教训**:
- **每次 reboot 后只能跑 1~2 次测试！** 第三个跑大概率崩
- **如果非跑不可→开原神压内存** 触发 shrinker+compaction 回收 slab（玄学但比干等强）
- **跑之前先验证 slab 状态**（理想情况，但 `/proc/slabinfo` 可能被 SELinux 封）

### Bug: prepare_kernel_page 没有自我保护
**根因**: `prepare_kernel_page()` 在 SLIDE 模式下 retry 12 次，每次都重新 clone 全部子进程。如果每次失败都留下僵尸 slab，12 次足够把内核榨干。
**建议修改**（源码待改）: 
- 首次失败后 `sleep(2)` 等待内核 GC
- 或者限制 SLIDE retry 从 12 降到 4，不成功就退出等下次重启

---

## 🚨 Termux 弹退风险 — 重要教训！

**现象**: Termux 随时可能弹退/闪退/卡死，尤其在跑 exploit 期间。

**影响**:
- v31 源码树放在 `/tmp/CVE-2026-43499-popsicle/`，Termux 弹退后 `/tmp` 清空，**源码全部丢失**
- 修改了代码没存档 → 弹退 → 白改
- 跑完测试没保存输出 → 弹退 → 输出丢失，无法分析

**铁律**:
1. **所有源码必须放在项目目录 (`matisse_backup_essentials/`) 内，禁止放 `/tmp/`！**
2. **运行 .so 前，先更新 CHECKPOINT 文档记录当前状态**
3. **运行 .so 后，立刻 `tee` 输出到 `RXX_testN.txt` 保存**
4. **任何手动修改代码后，立刻 `cp` 备份到 matisse_backup_essentials**
5. **不要相信 Termux 会话会一直存活**

---

## 🚨 R8 教训 (2026-07-16) ★ NEW — Shizuku cp 写入全零文件

### R8: 部署了但完全没部署

**症状**: R8 部署后运行 → 手机重启。检查 /data/local/tmp/preload.so 发现：
- 大小正确 (108976 bytes)
- SHA256: `7b2eedbc...` ≠ R8 真实哈希 `ce945969...`
- 内容: 全 0x00 字节 — file 命令识别为 "data" 而非 ELF

**根因**: Shizuku/rish 的 mount namespace 隔离下，`cp` 命令执行了 truncate (创建正确大小的文件) 但写入数据阶段失败 → 留下全零僵尸文件。LD_PRELOAD 全零文件直接报错不会导致重启 → **真正运行的必定是 rish namespace 里残留的旧版 .so！**

**教训**:
- **部署后必须验证哈希！** `cp` 后立刻 `sha256sum` 对比源文件，不一致绝不动
- **全零文件 = 部署失败，且旧文件已残留** → rish namespace 里可能跑着不知什么版本的 .so
- **每次部署前先 rm -f 目标文件** → 防止 cp 不覆盖
- **cp 后必须 sync** → 确保写入落盘

### ★ 从此固化：deploy.sh 脚本

```bash
bash /sdcard/Documents/matisse_backup_essentials/scripts/deploy.sh preload_mtk_RXX.so
```

脚本自动完成：源哈希 → rm + cp → sync → 目标哈希 → 对比 → 不一致则报警退出。

---

## 🚨 R11 教训 (2026-07-16) ★ NEW — init_task vs fake_task

### 发现: R8_test4 crash 的根因不是 GhostLock 本身，是 fake_task

**对照分析**:
| 路径 | waiter->task 值 | 结果 |
|------|----------------|------|
| slide.c (slide route) | SLIDE_INIT_TASK (真实 init_task) | ✅ 不崩, phase6 leaked 成功 |
| fops.c (main route) | fake_task (喷的页上的假结构) | ❌ pselect 期间 kernel panic |

**原因**: 内核在 PI chain walk 中访问 waiter->task 的字段 (priority, uclamp, pi_waiters...),
假 task_struct 含无效指针 → panic。真正的 init_task 所有字段有效 → 安全。

**修复**: 把 fops.c `prepare_pselect_fdsets()` 中 word[10] 从 `fake_task` 改为 `canon_addr(INIT_TASK)`。
一行改动可能让 R 系列 GhostLock write 全都不崩。

### 发现: v 系列不一定是死路

v30 判定 "rb_erase 永远只能写 name_ptr" 的结论是**从 rb_erase 视角**正确的, 但遗漏了:
**R 系列证明 GhostLock 写原语 (shape=1) 能成功写入任意内核地址！**

v+R 混合路线: 用 R 系列 GhostLock shape=1 + init_task 直接写 ASHMEM_MISC_FOPS,
绕过 rb_erase csel 限制。只需 1 次写, 不需要 per-CPU delta, 不需要 current task。

---

## 📝 给后续 AI/开发者的备忘

1. **先读本文件** — 检查方案是否已在死路清单
2. **Termux 弹退风险** — 源码放项目目录，测试前后必留档！
3. **v 系列终结于 v30** — rb_erase 路线已死，R 系列全新编号重启
4. **sprayed page 假树已死** — 三次失败, 不再试
5. **tree_pc 必须用 OFF|RED 才触发** — 已扫描确认
6. **ret>0 证明 type confusion 工作** — 不是框架问题, 是写入偏移问题
7. **configfs_read_once 返回 0 不代表没写入** — 是读取路径问题!
8. **FOPS-8 在 tree_entry 单独不触发** — 但在 pi_tree + OFF 协同下可能不同
9. **每次重启后测试** — MTK 内核 slab 容易耗尽

---

## 🚨 R7 教训 (2026-07-16) ★ NEW — build 目录陷阱

### R7_test1: 源码改了但二进制没变
**症状**: 
- 源码 common.h: `MM_STRUCT_SZ 0x3C0`, `SLIDE_KERNEL_PAGE_SETUP_ATTEMPTS 1`
- R7 二进制实际: `MM_STRUCT_SZ=0x500 (prepare=200)`, `retry=5`
- SHA256 和 R5/R6 不同 → 让人以为重新编译了
- 实际上 `make` 没有检测到 .h 变化，复用了旧的中间产物

**铁证**:
```
prepare=200 → mm_objs_per_slab=25 → MM_STRUCT_SZ=0x500 (旧值，错)
prepare=272 → mm_objs_per_slab=34 → MM_STRUCT_SZ=0x3C0 (新值，对)

v25 的 prepare=272 证明 0x3C0 是对的
R7 的 prepare=200 证明 0x500 还在二进制里
```

**教训**:
- **`make clean` 不可靠！用 `rm -rf build/` 直接删！**
- **编译后不能只看 SHA256 不同 → 要验证运行输出**
- **prepare 计数是 MM_STRUCT_SZ 的铁证 → 200=错 272=对**
- **这是 R2=R1 的重演，但更隐蔽（SHA256 变了但参数没变）**

---

## 🚨 R3 教训 (2026-07-16)

### R3_test1: 又是 uid=0 直接跑
**症状**: `uid=0 attr=untrusted_app_27` → `Permission denied` → 没走 Shizuku
**原因**: Termux 里直接 `LD_PRELOAD=... /system/bin/sleep 10` → 进程继承 Termux 的 SELinux context (untrusted_app_27)，不经过 Shizuku 提权
**教训**: 必须先进入 rish shell (Shizuku)，在 rish 内部署和运行 .so
- rish 内部 uid=2000 shell → 可以读 /proc/PID/mem
- Termux 直接跑 uid=0 但 SELinux=untrusted_app_27 → /proc/PID/mem 被封

### 用户反馈：R3 依旧重启
虽然 R3_test1 日志显示 Permission denied 退出，但后续再次尝试时仍触发重启。
说明即使 uid 正确，slab 耗尽仍是核心问题 → **sleep 微调是正确方向**

### ★ prepare_good_kernel_page 无 sleep 是根因
```
util.c:585-597 — 重试循环无任何延迟！
每次 prepare_kernel_page() = clone 272+204+33+34 子进程 + heap spray + SKB reclaim
SLIDE 模式重试 12 次无间隔 → slab 必然耗尽 → reboot
```
**修复方向**:
1. retry 之间加 `sleep(2)` 等内核 GC
2. SLIDE_KERNEL_PAGE_SETUP_ATTEMPTS 从 12 降到 5
3. slide_leak_kernel_base 外层重试之间也加 `sleep(3)`
