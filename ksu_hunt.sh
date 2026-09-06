#!/data/data/com.termux/files/usr/bin/bash
# ★ KSU 狩猎 v4 — 飞行记录仪模式 (实时落盘, 崩溃前状态永可回放) ★
# 启动: bash ~/ksu_hunt.sh [轮数]
RISH=$HOME/rish
LOG=/data/local/tmp/cstrike_log.txt
EV=/sdcard/Documents/matisse_backup_essentials/hunt_evidence
ST=/data/local/tmp/ksu_hunt_state.txt
FLIGHT=/data/local/tmp/flight.txt
MAX=${1:-20}
ROLL=0
mkdir -p $EV

# ── 启动尸检: boot_id 变了 = 上轮崩过 ──
OLD_BOOT=$(cat /data/local/tmp/hunt_boot_id.txt 2>/dev/null)
CUR_BOOT=$($RISH -c 'cat /proc/sys/kernel/random/boot_id' 2>/dev/null | tr -d '\r' | cut -c1-8)
if [ -n "$OLD_BOOT" ] && [ "$CUR_BOOT" != "$OLD_BOOT" ]; then
  TS=$(date +%m%d_%H%M); D=$EV/postmortem_$TS; mkdir -p $D
  echo "[尸检] $OLD_BOOT → $CUR_BOOT"
  $RISH -c "getprop ro.boot.bootreason" > $D/bootreason.txt 2>/dev/null
  $RISH -c "cp /data/local/tmp/flight.txt /data/local/tmp/cstrike_log.txt $D/ 2>/dev/null" 2>/dev/null
  $RISH -c "cp /data/local/tmp/R.out /data/local/tmp/C2.out /data/local/tmp/E5.out $D/ 2>/dev/null" 2>/dev/null
  grep -aE "pc :|Unable to handle|Internal error|Call trace" $D/console-ramoops.txt 2>/dev/null | head -8 > $D/panic_summary.txt
  echo "[尸检] panic 摘要:"; head -4 $D/panic_summary.txt 2>/dev/null
fi
echo "$CUR_BOOT" > /data/local/tmp/hunt_boot_id.txt

# ── 清场 + 归档函数 ──
cleanup() {
  $RISH -c 'pkill -9 -x sleep 2>/dev/null; pkill -9 -f "[p]reload\.so" 2>/dev/null; pkill -9 -f "[P]SELECT" 2>/dev/null' 2>/dev/null
}
archive() {
  RN=$1; TS=$(date +%m%d_%H%M); D=$EV/roll_$RN\_$TS; mkdir -p $D
  $RISH -c "cp /data/local/tmp/R.out /data/local/tmp/E5.out /data/local/tmp/C2.out /data/local/tmp/E5R.out /data/local/tmp/cstrike_log.txt /data/local/tmp/mt49_child_status.txt /data/local/tmp/flight.txt $D/ 2>/dev/null" 2>/dev/null
  echo "  [归档] $D (含 flight.txt 全程记录)"
}

echo "=== KSU HUNT v4 $(date +%T) max=$MAX 轮 (飞行记录仪模式) ==="
for ((ROLL=1; ROLL<=MAX; ROLL++)); do
  LOAD=$($RISH -c 'cut -d" " -f1 /proc/loadavg' 2>/dev/null | tr -d '\r')
  echo "[roll $ROLL/$MAX] load=${LOAD:-?} $(date +%T)"
  # ── 飞行记录仪: 10s 采样 线程wchan + load + boot + 轮次日志尾 ──
  $RISH -c 'rm -f /data/local/tmp/flight.txt; (while :; do TS=$(date +%T); LOAD=$(cut -d" " -f1 /proc/loadavg 2>/dev/null); BOOT=$(cat /proc/sys/kernel/random/boot_id 2>/dev/null | cut -c1-8); echo "[$TS] boot=$BOOT load=$LOAD" >> /data/local/tmp/flight.txt; for p in $(pgrep -x sleep 2>/dev/null); do WC=""; for t in /proc/$p/task/*; do WC="$WC $(basename $t):$(cat $t/wchan 2>/dev/null):$(cut -d" " -f3 $t/stat 2>/dev/null)"; done; echo "  pid=$p wchan=$WC" >> /data/local/tmp/flight.txt 2>/dev/null; done; tail -c 200 /data/local/tmp/R.out 2>/dev/null | tr -d "\000" | tail -1 >> /data/local/tmp/flight.txt 2>/dev/null; sleep 10; done) > /dev/null 2>&1 & echo $! > /data/local/tmp/flight_mon.pid' 2>/dev/null
  # ── 发射轮次 ──
  $RISH -c "sh /data/local/tmp/run_c_strike.sh" > /data/local/tmp/hunt_last.out 2>&1
  $RISH -c 'kill $(cat /data/local/tmp/flight_mon.pid 2>/dev/null) 2>/dev/null; pkill -f "flight_mon" 2>/dev/null' 2>/dev/null
  # ── 判据 1: KSU 模块加载 ──
  KSU=$($RISH -c 'grep -c ksu /proc/modules 2>/dev/null' 2>/dev/null | tr -d '\r ')
  if [ "${KSU:-0}" -ge 1 ]; then
    echo "★★★ [$ROLL] SUCCESS: KSU 模块已加载 — 持久 root 完成 ★★★"
    echo "SUCCESS-ksu" >> $ST; archive $ROLL; break
  fi
  # ── 判据 2: C 落地 (主观 cred 日志) ──
  EV=$($RISH -c 'grep -ah "ROOT-SEEN.*euid=0\|after setres uid=0" /data/local/tmp/R.out /data/local/tmp/C2.out /data/local/tmp/cstrike_log.txt 2>/dev/null | tail -2' 2>/dev/null | tr -d '\r')
  if [ -n "$EV" ]; then
    echo "★★★ [$ROLL] SUCCESS: C 落地实证 ★★★"; echo "$EV"
    echo "SUCCESS-C-landed" >> $ST; archive $ROLL; break
  fi
  # ── 判据 3: 信标 ──
  HN=$($RISH -c 'uname -n' 2>/dev/null | tr -d '\r')
  if [ "$HN" = "glroot" ]; then
    echo "★★★ [$ROLL] SUCCESS: glroot 信标 ★★★"
    echo "SUCCESS-beacon" >> $ST; archive $ROLL; break
  fi
  # ── 失败: 清场 + 归档 (flight.txt 含崩溃前全程) ──
  cleanup
  archive $ROLL
  BOOT2=$($RISH -c 'cat /proc/sys/kernel/random/boot_id' 2>/dev/null | tr -d '\r' | cut -c1-8)
  if [ "$BOOT2" != "$CUR_BOOT" ]; then
    echo "[roll $ROLL] 手机重启了 ($CUR_BOOT→$BOOT2), 重启手机+恢复Shizuku+重跑本脚本继续"
    echo "REBOOTED" >> $ST
    break
  fi
  echo "[roll $ROLL] 未中, 45s 冷却"
  sleep 45
done
echo "=== KSU HUNT end $(date +%T) — 证据: $EV | flight: /data/local/tmp/flight.txt ==="
