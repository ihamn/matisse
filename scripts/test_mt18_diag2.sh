#!/system/bin/sh
# mt18-diag2: 日志走 /data/local/tmp 避开 FUSE; preload 输出直接落文件
SRC=/sdcard/Documents/matisse_backup_essentials/preload_mt18_diag.so
DST=/data/local/tmp/preload.so
RUNLOG=/data/local/tmp/mt18_run.out
LOGBASE=/sdcard/Documents/matisse_backup_essentials/logs
LOG=$LOGBASE/mt18_diag2.txt

echo "=== [1/5] 部署 ==="
rm -f $DST; cp $SRC $DST; sync
SRC_H=$(sha256sum $SRC | awk '{print $1}')
DST_H=$(sha256sum $DST | awk '{print $1}')
[ "$SRC_H" = "$DST_H" ] || { echo "HASH MISMATCH"; exit 1; }
echo "HASH OK"

echo "=== [2/5] am kill-all ==="
am kill-all 2>&1 | tail -1
echo "boot_before=$(cat /proc/sys/kernel/random/boot_id)" > $LOG

echo "=== [3/5] 运行 (30s 超时保护) ==="
rm -f $RUNLOG
timeout 90 env LD_PRELOAD=$DST /system/bin/sleep 60 > $RUNLOG 2>&1
RC=$?
echo "run_rc=$RC" >> $LOG
cat $RUNLOG >> $LOG
echo "=== [4/5] boot_id 后 ==="
echo "boot_after=$(cat /proc/sys/kernel/random/boot_id)" >> $LOG
echo "=== DONE ===" >> $LOG
