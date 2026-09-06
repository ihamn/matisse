#!/data/data/com.termux/files/usr/bin/bash
# ★ KSU 狩猎 v3 — 失败自动清场 + 证据自动归档 + 崩溃尸检 ★
# 启动: bash ~/ksu_hunt.sh [轮数]
RISH=$HOME/rish
LOG=/data/local/tmp/cstrike_log.txt
EV=/sdcard/Documents/matisse_backup_essentials/hunt_evidence
ST=/data/local/tmp/ksu_hunt_state.txt
MAX=${1:-20}
ROLL=0
mkdir -p $EV

# ── 启动尸检: boot_id 变了 = 上轮崩过 → 收 pstore/bootreason ──
OLD_BOOT=$(cat /data/local/tmp/hunt_boot_id.txt 2>/dev/null)
CUR_BOOT=$($RISH -c 'cat /proc/sys/kernel/random/boot_id' 2>/dev/null | tr -d '\r' | cut -c1-8)
if [ -n "$OLD_BOOT" ] && [ "$CUR_BOOT" != "$OLD_BOOT" ]; then
  TS=$(date +%m%d_%H%M)
  D=$EV/postmortem_$TS
  mkdir -p $D
  echo "[尸检] boot 变更 $OLD_BOOT → $CUR_BOOT, 收取现场..."
  $RISH -c "getprop ro.boot.bootreason" > $D/bootreason.txt 2>/dev/null
  $RISH -c "cat /sys/fs/pstore/console-ramoops-0" > $D/console-ramoops.txt 2>/dev/null
  $RISH -c "cp /data/local/tmp/cstrike_log.txt /data/local/tmp/hunt_last.out $D/ 2>/dev/null" 2>/dev/null
  grep -aE "pc :|Unable to handle|Internal error|Call trace" $D/console-ramoops.txt 2>/dev/null | head -8 > $D/panic_summary.txt
  echo "[尸检] panic 摘要:"; head -4 $D/panic_summary.txt 2>/dev/null
fi
echo "$CUR_BOOT" > /data/local/tmp/hunt_boot_id.txt

# ── 清场函数: 杀残留进程 ──
cleanup() {
  $RISH -c 'pkill -9 -x sleep 2>/dev/null; pkill -9 -f "[p]reload\.so" 2>/dev/null; pkill -9 -f "[P]SELECT" 2>/dev/null' 2>/dev/null
  echo "  [清场] 残留进程已清"
}

# ── 证据归档函数 ──
archive() {
  RN=$1; TS=$(date +%m%d_%H%M)
  D=$EV/roll_$RN\_$TS
  mkdir -p $D
  $RISH -c "cp /data/local/tmp/R.out /data/local/tmp/E5.out /data/local/tmp/C2.out /data/local/tmp/E5R.out /data/local/tmp/cstrike_log.txt /data/local/tmp/mt49_child_status.txt $D/ 2>/dev/null" 2>/dev/null
  echo "  [归档] $D"
}

echo "=== KSU HUNT v3 $(date +%T) max=$MAX 轮 ==="
for ((ROLL=1; ROLL<=MAX; ROLL++)); do
  LOAD=$($RISH -c 'cut -d" " -f1 /proc/loadavg' 2>/dev/null | tr -d '\r')
  echo "[roll $ROLL/$MAX] load=${LOAD:-?} $(date +%T)"
  $RISH -c "sh /data/local/tmp/run_c_strike.sh" > /data/local/tmp/hunt_last.out 2>&1
  # 判据 1: KSU 模块加载 (终局)
  KSU=$($RISH -c 'grep -c ksu /proc/modules 2>/dev/null' 2>/dev/null | tr -d '\r ')
  if [ "${KSU:-0}" -ge 1 ]; then
    echo "★★★ [$ROLL] SUCCESS: KSU 模块已加载 — 持久 root 完成 ★★★"
    echo "SUCCESS-ksu" >> $ST
    archive $ROLL
    break
  fi
  # 判据 2: C 落地 (主观 cred, 日志判据)
  EV=$($RISH -c 'grep -ah "ROOT-SEEN.*euid=0\|after setres uid=0" /data/local/tmp/R.out /data/local/tmp/C2.out /data/local/tmp/cstrike_log.txt 2>/dev/null | tail -2' 2>/dev/null | tr -d '\r')
  if [ -n "$EV" ]; then
    echo "★★★ [$ROLL] SUCCESS: C 落地实证 (主观 cred euid=0) ★★★"
    echo "$EV"
    echo "SUCCESS-C-landed" >> $ST
    archive $ROLL
    break
  fi
  # 判据 3: 信标
  HN=$($RISH -c 'uname -n' 2>/dev/null | tr -d '\r')
  if [ "$HN" = "glroot" ]; then
    echo "★★★ [$ROLL] SUCCESS: hostname=glroot 信标 ★★★"
    echo "SUCCESS-beacon" >> $ST
    archive $ROLL
    break
  fi
  # ── 失败处理: 清场 + 归档 ──
  cleanup
  archive $ROLL
  BOOT2=$($RISH -c 'cat /proc/sys/kernel/random/boot_id' 2>/dev/null | tr -d '\r' | cut -c1-8)
  if [ "$BOOT2" != "$CUR_BOOT" ]; then
    echo "[roll $ROLL] 手机已重启 (boot $CUR_BOOT→$BOOT2), 等待 Shizuku 恢复后本脚本重启即可继续"
    echo "REBOOTED" >> $ST
    break
  fi
  grep -aE "R LANDED|R MISS|C rc=|C ABORT" $LOG 2>/dev/null | tail -2 | while read -r l; do
    echo "[roll $ROLL] $l"
  done
  echo "[roll $ROLL] 未中, 45s 冷却重掷"
  sleep 45
done
echo "=== KSU HUNT end $(date +%T) — 状态: $(tail -1 $ST 2>/dev/null) 证据: $EV ==="
