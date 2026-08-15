# Checkpoint: 2026-07-15 重启后恢复

## 二进制: preload_mtk_v28_fix2.so
  MD5: b2ee495504a73edfe9b848d3c1b319d0
  大小: 162224 bytes
  状态: 编译完成, 已部署到 /data/local/tmp/preload.so

## 当前状况
- v28_fix2 稳定运行 (5个MTK cooldown), SLIDE+FOPS通过
- GhostLock race 触发 (ret=175-199, calls=1, success=1)
- **FOPS 仍未覆盖** — try_cfi_stage 返回 ret=-1 errno=22 (EINVAL)

## rb_erase 反汇编深入分析结论

### 三条 erase 路径

| 路径 | 条件 | csel 写入位置 | 当前结果 |
|------|------|-------------|---------|
| Path A (left=NULL) | tree_left=0 | parent+0x08 (rb_right) | → name_ptr (OFF+0x08) |
| Path B (right=NULL) | tree_right=0 | parent+0x10 (rb_left) | → fops (OFF+0x10) 但不触发 |
| Path C (both≠NULL) | 两者非零 | parent+0x08 (rb_right) | → name_ptr (仅一次写入!) |

### 关键发现: Path C 不是两次写入!
当 successor->rb_left == NULL (我们的情况), rb_erase 跳过"erase successor from old position"步骤.
只有一次写入: replace node with successor → parent->rb_{left,right} = successor.
csel 永远选 rb_right → 永远写 parent+0x08 = name_ptr.

### pi_tree_entry (pi_parent=FOPS-8|RED) — 理论上的解
Path A for pi_tree_entry:
  parent=FOPS-8 → parent->rb_right=*(FOPS-8+0x08)=*(FOPS)=ashmem_fops
  → csel 比较 parent->rb_left(=list, 0) vs node(栈地址) → 不匹配
  → 选 rb_right → 写入 parent+0x08 = FOPS! ← 目标!

**为什么不生效?**
  rt_mutex_adjust_prio_chain 的三个 rb_erase 调用:
    Call 1 (0x1eb328): x28(top_waiter) from lock->waiters → 用 tree_entry
    Call 2 (0x1eb8f8): &pi_tree_entry from pi_waiters → **也是用 pi_tree_entry!**
    Call 3 (0x1ebedc): &pi_tree_entry from pi_waiters → **也是用 pi_tree_entry!**

  Call 2 前检查: waiter->lock == lock? (line 0x1eaf2c-34)
    如果 GhostLock 破坏了 waiter->lock → fake_lock ≠ real_lock → bail!

## 下一步方向

### 方向 1: 确保 pi_tree_entry 的 rb_erase 运行
  - 需要 waiter->lock == real_lock 的检查通过
  - 可能需要调整 fd_set 中的 lock 值 (word 7)
  - 或者找到绕过检查的方法

### 方向 2: 尝试简单 Path A (tree_left=0) 
  - 设置 PSELECT_PAT_C0=1 退回 Path A
  - 减少 Path C 的额外写入导致的副作用
  - tree_left=0 比 tree_left=fake_fops 更干净

### 方向 3: 调试输出
  - 在 dmesg/logcat 中查找内核日志
  - 确认哪个 rb_erase 实际运行了

### 方向 4: 不同 env var 组合
  - PSELECT_PI_PARENT (hex) — pi_tree_entry parent
  - PSELECT_PI_RIGHT (hex) — pi_tree_entry rb_right  
  - PSELECT_PI_LEFT  (hex) — pi_tree_entry rb_left
  - PSELECT_TREE_LEFT (hex) — tree_entry rb_left
  - PSELECT_LOCK (hex) — waiter->lock

## 源码位置
  /mnt/sdcard/Documents/matisse_backup_essentials/CyberMeowfia/IonStack/CVE-2026-43499/exploit/

## 编译命令
  cd /mnt/sdcard/Documents/matisse_backup_essentials/CyberMeowfia/IonStack/CVE-2026-43499/exploit
  make PROJECT=matisse-OS2.0.6.0.ULKCNXM API=34 CC=clang

## 部署和运行
  cp build/matisse-OS2.0.6.0.ULKCNXM/bin/preload.so /mnt/sdcard/Documents/matisse_backup_essentials/preload_mtk_v29.so
  # 通过 Shizuku:
  RISH_APPLICATION_ID=com.termux /system/bin/app_process -Djava.class.path=/data/local/tmp/rish_shizuku.dex /system/bin --nice-name=rish rikka.shizuku.shell.ShizukuShellLoader
  cp /sdcard/Documents/matisse_backup_essentials/preload_mtk_v29.so /data/local/tmp/preload.so
  LD_PRELOAD=/data/local/tmp/preload.so /system/bin/sleep 10 2>&1

## env var 测试
  LD_PRELOAD=/data/local/tmp/preload.so PSELECT_PAT_C0=1 /system/bin/sleep 10 2>&1
  LD_PRELOAD=/data/local/tmp/preload.so PSELECT_TREE_LEFT=0 /system/bin/sleep 10 2>&1
