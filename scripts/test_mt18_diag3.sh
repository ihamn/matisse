#!/system/bin/sh
# mt18-diag3: oracle 环境 + ks 重试 + 日志走 /data/local/tmp
SRC=/sdcard/Documents/matisse_backup_essentials/preload_mt18_diag.so
DST=/data/local/tmp/preload.so
RUNLOG=/data/local/tmp/mt18_run3.out
LOG=/sdcard/Documents/matisse_backup_essentials/logs/mt18_diag3.txt

echo "=== [1/5] 部署 ==="
rm -f $DST; cp $SRC $DST; sync
SRC_H=$(sha256sum $SRC | awk '{print $1}')
DST_H=$(sha256sum $DST | awk '{print $1}')
[ "$SRC_H" = "$DST_H" ] || { echo "HASH MISMATCH"; exit 1; }
echo "HASH OK"

echo "=== [2/5] am kill-all ==="
am kill-all 2>&1 | tail -1
echo "boot_before=$(cat /proc/sys/kernel/random/boot_id)" > $LOG

echo "=== [3/5] 运行 (oracle env, 180s 上限) ==="
rm -f $RUNLOG
timeout 180 env \
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
  LD_PRELOAD=$DST /system/bin/sleep 120 > $RUNLOG 2>&1
RC=$?
echo "run_rc=$RC" >> $LOG
cat $RUNLOG >> $LOG
echo "=== [4/5] boot_id 后 ==="
echo "boot_after=$(cat /proc/sys/kernel/random/boot_id)" >> $LOG
echo "=== DONE ===" >> $LOG
