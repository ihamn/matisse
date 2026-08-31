#!/system/bin/sh
# Create a clean live target task for external-mode experiments (mt70).
# Forks a child that leaks its task and then polls for 8 minutes.
# Parent prints mt70: HOLDER task=... and exits without any write.
#
# Run with mt70 preload deployed. After this, /data/local/tmp/mt49_child_status.txt
# contains the live task with original creds (uid=2000 euid=2000 CapEff=0).
LOG=/data/local/tmp/holder_log.txt
echo "=== HOLDER start $(date +%H:%M:%S) ===" > $LOG
am kill-all 2>/dev/null
rm -f /data/local/tmp/mt49_child_status.txt /data/local/tmp/root_alive.txt
timeout 150 env \
  PSELECT_SLIDE_TRIGGER=1 PSELECT_CRED=1 PSELECT_PERF_CRED=1 \
  PSELECT_HOLDER=1 PSELECT_SKIP_WARMUP=1 PSELECT_WAIT_SECONDS=10 \
  LD_PRELOAD=/data/local/tmp/preload.so /system/bin/sleep 20 \
  > /data/local/tmp/Holder.out 2>&1
echo "HOLDER rc=$? boot=$(cat /proc/sys/kernel/random/boot_id)" >> $LOG
echo "--- status ---" >> $LOG
cat /data/local/tmp/mt49_child_status.txt 2>/dev/null >> $LOG
echo "--- holder marker ---" >> $LOG
grep -a "mt70: HOLDER task=\|mt33: child pid=\|mt49: external" /data/local/tmp/Holder.out 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | head -10 >> $LOG
cat $LOG
