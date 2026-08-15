# AI 留档快照 — 2026-07-16 (R10 崩溃分析 + R11 编译部署 + v系列重新评估)

## 本次 AI 做了什么

### 1. 诊断 R10 崩溃
- **根因: R10 从未部署！** `/data/local/tmp/preload.so` SHA256 = `ce945969` (R8), 不是 `90ac1a40` (R10)
- R10_test1 实际运行的是 R8 → kernel panic → 日志全 NULL (2692 bytes of 0x00)
- R10_test1.txt vs R9_test1.txt 对比: R9 至少前5行有内容, R10 连 deploy.sh 和 "preload starting" 都没有

### 2. 编译部署 R11
- 修复内容:
  a. fflush 加固: page holder fork 前后 + 关键路径
  b. pipe read 120s 超时: 防止 holder 卡死
  c. DIRECT_PCPU_DELTA 环境变量: 跳过 GhostLock shape=0 读 (这个读原语是 R8_test4 panic 的直接原因)
  d. FOPS reprepare 加固: page holder 和 write child 都调用 prepare_skb_payload(FOPS)
- 文件: preload_mtk_R11.so (111368 bytes)
- SHA256: 8319656ae65a843367300a0f0149bbd86a5ca956edbb65963a3c82752dd40b56
- 编译: 0 errors, 0 warnings
- ★ 已部署到 /data/local/tmp/preload.so 并验证哈希一致

### 3. 深度重新评估 v 系列 — 不一定是死路！

#### v 系列历史回顾
- v1-v30: 尝试通过 GhostLock rb_erase 覆写 ashmem miscdevice fops
- v30 反汇编结论: rt_mutex_adjust_prio_chain 只有 2 次 rb_erase
  - Call 1: rb_erase(&waiter->tree_entry, &lock->waiters) → 写 OFF+0x08 = name_ptr
  - Call 2: rb_erase(&waiter->tree_entry, &task->pi_waiters) → 同样写 OFF+0x08
  - **没有 Call 3! pi_tree_entry 从未被 erase**
- csel 永远选 rb_right → 永远写 parent+0x08 (name_ptr), 永远碰不到 parent+0x10 (fops)
- v29 Deep PI Chain: 创建了 3-thread PI chain 试图让 Call 2/3 执行 → 从未成功
- v30 结论: "GhostLock rb_erase 永远只能写 name_ptr, FOPS 无法通过 rb_erase 覆写" → 关闭

#### ★ 新发现: 为什么 R8_test4 crash 而 slide 路径不 crash

对比 fops.c (R序列 main route) 和 slide.c (slide route) 的 pselect fd_set 编码:

```
字段          main route (CRASH)        slide route (OK)
─────────────────────────────────────────────────────────
word[0] (pc)  target/value dependent   SLIDE_LOGGERS_0_1
word[10] task FAKE_TASK (sprayed page)  SLIDE_INIT_TASK (real init_task)
word[11] lock fake_lock                 fake_lock
```

**根因**: main route 的 `fake_task` 在喷的 slab page 上。内核在 PI chain walk 中调
`rt_mutex_adjust_prio_chain()` 时访问 waiter->task 的字段 (priority, uclamp, pi_waiters...),
fake_task 有无效值 → kernel panic。slide 路径用 `SLIDE_INIT_TASK` (= 真正的 init_task),
所有字段有效 → 安全。

`fake_lock` 两者相同, 所以 lock 不是问题。区别全在 task 指针。

#### 两条复活路线

**路线 A: 修复 R 序列 (1 行改动)**
- 改 fops.c: `{10, fake_task, "task"}` → `{10, canon_addr(INIT_TASK), "task"}`
- GhostLock shape=1 write 不崩 (因为 init_task 有效)
- 仍需硬编码 DIRECT_PCPU_DELTA (跳过 shape=0 per-CPU 读)
- 风险: shape=0 读仍会崩 (写入目标是 percpu_slot, 不是 task 问题)

**路线 B: v+R 混合 — GhostLock 直接写 FOPS (最优)**
- 用修复后的 GhostLock (init_task + shape=1) 写 fake_fops 到 ASHMEM_MISC_FOPS:
  - target = ASHMEM_MISC_FOPS (= 0xffffffc00a8e76e8)
  - value = page_base + FOPS_OFF (喷的页上的假 file_operations)
  - shape = 1 → parent = target-8 → parent->rb_right = FOPS
  - csel 选 rb_right (因为 parent->rb_left 含内核数据 ≠ node 栈地址) → 写 value 到 FOPS ✅
- 只需要 1 次 GhostLock 写 (不需要 per-CPU leak, 不需要 current task)
- 写完 FOPS 后通过 /dev/ashmem ioctl/mmap 做任意内核 R/W

**混合路线的关键优势**:
1. 不碰 per-CPU offset 表 → 不会触发 shape=0 崩溃
2. 用 init_task 替代 fake_task → GhostLock 不崩
3. 只写 1 个地址 (FOPS) → 最小化内核损坏
4. FOPS 在 writable data section → 没有页故障
5. 覆写 FOPS 后获得持续的内核 R/W 能力 (configfs 路线)
6. 不需要 DIRECT_PCPU_DELTA 硬编码

### 4. 更新的文档
- !!!_AI_READ_THIS_FIRST.md: 全面更新 (R11 状态, R10 崩溃原因, DIRECT_PCPU_DELTA 用法)
- CHECKPOINT_R11_analysis.md: 新建 (深度分析: GhostLock 读原语为什么崩, per-CPU 问题)
- main.c: R11 改动 (fflush, pipe timeout, DIRECT_PCPU_DELTA, FOPS reprepare)
- pipe.c: R11 改动 (FOPS reprepare in reuse path)
- 部署: R11 已正确部署到 /data/local/tmp/preload.so (哈希验证通过)

### 5. 物理文件变更
- preload_mtk_R11.so: 新建 (SHA256: 8319656a...)
- build/ 目录已重建
- /data/local/tmp/preload.so: 已更新为 R11
- /data/local/tmp/preload.so.bak: R8 备份

## 当前状态总结

| 项目 | 状态 |
|------|------|
| R11 部署 | ✅ /data/local/tmp/preload.so = R11 |
| R11 测试 | ⏳ 待用户从 rish 运行 |
| DIRECT_PCPU_DELTA | ❓ 未知, 需从成功运行中提取 |
| v 系列重新评估 | 🔄 发现 init_task vs fake_task 关键差异 |
| 路线 A (修复 R 系列) | 💡 1行改动, 待实现 |
| 路线 B (v+R 混合 FOPS) | 💡 最优方案, 待实现 |

## 下次继续的关键点

1. **立即**: 从 rish 运行 R11_test1
   ```bash
   RISH_APPLICATION_ID=com.termux /system/bin/app_process \
     -Djava.class.path=/data/local/tmp/rish_shizuku.dex \
     /system/bin --nice-name=rish rikka.shizuku.shell.ShizukuShellLoader
   # rish 内:
   LD_PRELOAD=/data/local/tmp/preload.so /system/bin/sleep 10 2>&1 | \
     tee /sdcard/Documents/matisse_backup_essentials/logs/R11_test1.txt
   ```
   期望: 至少看到 "direct-fusion: forking page holder..." (新增 fflush 确保可见)

2. **如果 test1 崩**: 分析日志, 关注是否打印了 delta 值。如果打印了, 用那个值跑 test2:
   ```bash
   DIRECT_PCPU_DELTA=0x... LD_PRELOAD=... sleep 10 2>&1 | tee .../R11_test2.txt
   ```

3. **路线 A (如果 test1/2 仍崩)**: 改 fops.c 第 10 个 waiter word 为 `canon_addr(INIT_TASK)`,
   编译 R12 测试

4. **路线 B (如果路线 A 成功)**: 实现 GhostLock → FOPS 覆写, 不再需要 DIRECT_PCPU_DELTA

5. **手机重启后**: 最多跑 2 次测试, 第三次必崩 (MTK slab 扛不住)
