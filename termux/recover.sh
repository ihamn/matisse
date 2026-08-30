#!/data/data/com.termux/files/usr/bin/bash
# ============================================================
# matisse 断点回收脚本 v1 (评审维护, 零判断执行)
# 用途: 重启/中断后, 只回收现场数据并回传, 绝不开火
# 顺序纪律: 先跑本脚本, 看到推送成功后, 再等10分钟重跑 field_auto.sh
# ============================================================
set -u
TOKEN=$(cat "$HOME/.matisse_token" 2>/dev/null | tr -d ' \r\n' || true)
if [ -n "$TOKEN" ]; then
  REPO_URL="https://ihamn:${TOKEN}@gitee.com/ihamn/matisse.git"
else
  REPO_URL="https://gitee.com/ihamn/matisse.git"
  echo "[recover] 警告: 无令牌文件, 推送会失败(收集不受影响)"
fi
WORK="$HOME/matisse"
RUN_TS=$(date +%Y%m%d_%H%M%S)
PUSHED=0
command -v termux-wake-lock >/dev/null 2>&1 && termux-wake-lock 2>/dev/null
say(){ echo "[recover] $*"; }

# ---------- 0. 仓库 ----------
command -v git >/dev/null 2>&1 || pkg install -y git >/dev/null 2>&1 || { say "git 安装失败,检查网络"; exit 1; }
[ -d "$WORK/.git" ] || git clone -q "$REPO_URL" "$WORK" || { say "克隆失败,检查网络"; exit 1; }
cd "$WORK" || exit 1
git remote set-url origin "$REPO_URL"
git config user.name "field-termux"; git config user.email "field@termux.local"
git pull -q origin master 2>/dev/null || true
say "仓库就绪: $(git log --oneline -1 | cut -c1-70)"

# ---------- 1. rish (重启后 Shizuku 不会自己活!) ----------
RISH=""
for c in "$HOME/rish" "$HOME/rish/rish" "$HOME/storage/downloads/rish" \
         "/sdcard/Download/rish" "/storage/emulated/0/Download/rish" "/data/local/tmp/rish"; do
  [ -f "$c" ] && RISH="$c" && break
done
[ -z "$RISH" ] && RISH=$(find "$HOME" -maxdepth 3 -name rish -type f 2>/dev/null | head -1)
[ -z "$RISH" ] && { say "!! 没找到 rish (见 field_auto.sh 第1步的安装说明)"; exit 2; }
RISH_DIR=$(dirname "$RISH"); chmod +x "$RISH" 2>/dev/null
RISH_MODE=""
TEST_A=$( (cd "$RISH_DIR" && timeout 30 ./rish "echo RISH_OK_\$(id -u)") 2>&1 )
printf '%s' "$TEST_A" | grep -q "RISH_OK_" && RISH_MODE=args
if [ -z "$RISH_MODE" ]; then
  TEST_B=$( (cd "$RISH_DIR" && echo 'echo RISH_OK_$(id -u)' | timeout 30 ./rish) 2>&1 )
  printf '%s' "$TEST_B" | grep -q "RISH_OK_" && RISH_MODE=stdin
fi
if [ -z "$RISH_MODE" ]; then
  say "!! rish 连不上。手机重启后 Shizuku 不会自动启动:"
  say "   -> 打开 Shizuku app -> 点启动 -> 回 Termux 重新粘贴本脚本"
  exit 2
fi
say "rish 就绪 (模式 $RISH_MODE)"
rsh1(){ local cmd="$1" t="${2:-60}"
  if [ "$RISH_MODE" = args ]; then (cd "$RISH_DIR" && timeout "$t" ./rish "$cmd") 2>&1
  else printf '%s\n' "$cmd" | (cd "$RISH_DIR" && timeout "$t" ./rish) 2>&1; fi; }
rsh(){ local cmd="$1" t="${2:-60}" out i
  for i in 1 2 3 4; do
    out=$(rsh1 "$cmd" "$t")
    printf '%s' "$out" | grep -q "Request timeout\|blocked by your system" || { printf '%s\n' "$out"; return 0; }
    [ "$i" -lt 4 ] && say "Shizuku 闪断(第${i}次), 8秒后重试..." >&2
    sleep 8
  done
  printf '%s\n' "$out"; return 1; }

# ---------- 2. 收集 (只读, 零开火) ----------
say "第2步: 收集现场数据"
DEST="$WORK/logs_raw/recovery_${RUN_TS}"
mkdir -p "$DEST"
{ echo "# 回收时间 $RUN_TS"
  rsh "date; cat /proc/sys/kernel/random/boot_id; getenforce; cat /proc/uptime; cat /proc/loadavg" 30
} > "$DEST/device_state.txt" 2>&1
rsh "ls -la /data/local/tmp/" 30 > "$DEST/tmp_listing.txt" 2>&1
say "设备状态已存 (boot_id 在 device_state.txt)"
for f in R11 R12 R13 R14 C1 R9 R10 R7 R8; do
  rsh "cat /data/local/tmp/$f.out" 90 > "$DEST/${f}_raw.out" 2>/dev/null
  [ -s "$DEST/${f}_raw.out" ] || rm -f "$DEST/${f}_raw.out"
done
rsh "cat /data/local/tmp/mt49_child_status.txt" 30 > "$DEST/mt49_child_status.txt" 2>/dev/null
[ -s "$DEST/mt49_child_status.txt" ] || rm -f "$DEST/mt49_child_status.txt"
rsh "cat /data/local/tmp/root_alive.txt" 20 > "$DEST/root_alive.txt" 2>/dev/null
[ -s "$DEST/root_alive.txt" ] || rm -f "$DEST/root_alive.txt"
# 重启根因证据 (可读则黄金, 不可读也无所谓)
rsh "cat /sys/fs/pstore/console-ramoops* 2>/dev/null | tail -c 100000" 30 > "$DEST/pstore_tail.txt" 2>/dev/null
[ -s "$DEST/pstore_tail.txt" ] || rm -f "$DEST/pstore_tail.txt"
rsh "dumpsys dropbox --print 2>/dev/null | tail -c 200000" 60 > "$DEST/dropbox_tail.txt" 2>/dev/null
[ -s "$DEST/dropbox_tail.txt" ] || rm -f "$DEST/dropbox_tail.txt"
# Termux 侧: 最近3份控制台日志 (中断轮的直接记录)
for f in $(ls -t "$HOME"/card_console_*.log 2>/dev/null | head -3); do cp "$f" "$DEST/" 2>/dev/null; done

# ---------- 3. 摘要 (现场直接看, 不用等评审) ----------
say "第3步: 摘要"
if [ -f "$DEST/R11_raw.out" ]; then
  say "R11.out 存在 ($(wc -l < "$DEST/R11_raw.out") 行):"
  if grep -aq "mt61: pselect window" "$DEST/R11_raw.out"; then
    say "  - mt61 窗口标记存在 (新二进制开过火)"
    grep -a "mt61: pselect window\|pselect returned\|mt19b: sched attempt\|mt25: futex trigger 0" "$DEST/R11_raw.out" | head -6 | sed 's/^/  /'
    say "  - R11 最后 5 行:"; tail -5 "$DEST/R11_raw.out" | sed 's/^/  /'
  else
    say "  - 无 mt61 标记 (旧文件或火未及开)"
  fi
else
  say "R11.out 不存在 (重启发生在开火之前?)"
fi
BOOT_NOW=$(grep -a boot_id "$DEST/device_state.txt" 2>/dev/null | head -1 | cut -c1-50)
say "当前 boot: $BOOT_NOW"

# ---------- 4. 回传 ----------
say "第4步: 回传"
git add -A >/dev/null 2>&1
git commit -q -m "recovery ${RUN_TS}: post-reboot field collection (no fire) - R11 exists=$( [ -f "$DEST/R11_raw.out" ] && echo yes || echo no )" || true
for i in 1 2 3; do
  git pull -q --rebase origin master 2>/dev/null
  git push -q origin master 2>/dev/null && { PUSHED=1; break; }
  say "推送重试 $i..."; sleep 10
done
command -v termux-wake-unlock >/dev/null 2>&1 && termux-wake-unlock 2>/dev/null
say "=========================================="
if [ "$PUSHED" = 1 ]; then
  say "回收完成! 数据已推回 gitee"
  say "下一步: 等 10 分钟 (settle), 再粘贴 field_auto.sh 那一行重跑"
else
  say "推送失败! 把 \$HOME 下最新的 card_console_*.log 发给评审"
fi
