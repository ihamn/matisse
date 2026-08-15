#!/system/bin/sh
# mt15: deep chain + FOPS route + 扫 shift 0-7 + boot_id 验证
SRC=/sdcard/Documents/matisse_backup_essentials/preload_mt17_v30tech.so
DST=/data/local/tmp/preload.so
LOG=/sdcard/Documents/matisse_backup_essentials/logs/mt17_test1.txt

echo "=== [1/4] 部署 ==="
rm -f $DST; cp $SRC $DST; sync
SRC_H=$(sha256sum $SRC | awk '{print $1}')
DST_H=$(sha256sum $DST | awk '{print $1}')
[ "$SRC_H" = "$DST_H" ] || { echo "❌ 哈希不一致"; exit 1; }
echo "✅ 哈希一致"

echo "=== [2/4] boot_id 前 ==="
cat /proc/sys/kernel/random/boot_id | tee $LOG

echo "=== [3/4] 运行 (shift 扫描 + boot_id 验证) ==="
PSELECT_TREE_PC=ffffff80028a77c8 \
PSELECT_TREE_RIGHT=0 \
PSELECT_TREE_LEFT=0 \
PSELECT_PI_PARENT=0 \
PSELECT_PI_RIGHT=0 \
PSELECT_PI_LEFT=0 \
PSELECT_PAT_C0=1 \
PSELECT_SWEEP_SHIFTS=1 \
PSELECT_SWEEP_MAX=15 \
PSELECT_SKIP_WARMUP=1 \
LD_PRELOAD=$DST /system/bin/sleep 120 2>&1 | tee -a $LOG

echo "=== [4/4] boot_id 后 ==="
cat /proc/sys/kernel/random/boot_id | tee -a $LOG
echo "=== DONE ==="
