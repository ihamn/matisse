#!/system/bin/sh
# mt21 NULL-task marker: buf[6]=0 → walk 若读到 stamp 必崩 (July v37 实证)
SRC=/sdcard/Documents/matisse_backup_essentials/preload_mt21.so
DST=/data/local/tmp/preload.so
LOG=/sdcard/Documents/matisse_backup_essentials/logs/mt21_marker.txt
RUNLOG=/data/local/tmp/mt21_marker_run.out
rm -f $DST; cp $SRC $DST; sync
echo "boot_before=$(cat /proc/sys/kernel/random/boot_id)" > $LOG
am kill-all 2>&1 | tail -1
rm -f $RUNLOG
timeout 140 env \
  PSELECT_SLIDE_TRIGGER=1 \
  PSELECT_V37=1 \
  PSELECT_TREE_PC=ffffff80028a77c8 \
  PSELECT_TREE_LOCK=0 \
  PSELECT_TREE_TASK=0 \
  PSELECT_SKIP_WARMUP=1 \
  LD_PRELOAD=$DST /system/bin/sleep 100 > $RUNLOG 2>&1
echo "run_rc=$?" >> $LOG
grep -a 'mt21:\|FCRQ\|FLPI\|SLIDE page\|stext=' $RUNLOG | sed 's/\x1b\[[0-9;]*m//g' >> $LOG
echo "boot_after=$(cat /proc/sys/kernel/random/boot_id)" >> $LOG
echo "=== DONE ===" >> $LOG
