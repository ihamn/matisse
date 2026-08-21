#!/data/data/com.termux/files/usr/bin/bash
# ============================================================
# matisse R11 单文件重收集 v1 (评审维护, 零判断执行)
# 背景: 上次 recover.sh 第一笔 rsh 闪断返回空, 被误判成功,
#       R11.out 只回收了 1 字节 — 设备上完整文件 (1932字节) 还在。
# 本脚本: 只读回收 R11.out (字节校验+重试), 绝不开火。
# 纪律: 本脚本跑完推送成功后, 等评审的下一张卡, 别跑 field_auto.sh
# ============================================================
set -u
TOKEN=$(cat "$HOME/.matisse_token" 2>/dev/null | tr -d ' \r\n' || true)
if [ -n "$TOKEN" ]; then
  REPO_URL="https://ihamn:${TOKEN}@gitee.com/ihamn/matisse.git"
else
  REPO_URL="https://gitee.com/ihamn/matisse.git"
  echo "[r11] 警告: 无令牌文件, 推送会失败(收集不受影响)"
fi
WORK="$HOME/matisse"
RUN_TS=$(date +%Y%m%d_%H%M%S)
PUSHED=0
command -v termux-wake-lock >/dev/null 2>&1 && termux-wake-lock 2>/dev/null
say(){ echo "[r11] $*"; }
SHIZUKU_DEAD_HINT="!! Shizuku 连接不稳定。手机上做一次(只需一次): 设置->应用管理->Termux和Shizuku->省电策略都改[无限制], 运行期间插充电器+亮屏, 然后重新粘贴运行本脚本"

# ---------- 0. 仓库 ----------
command -v git >/dev/null 2>&1 || pkg install -y git >/dev/null 2>&1 || { say "git 安装失败,检查网络"; exit 1; }
[ -d "$WORK/.git" ] || git clone -q "$REPO_URL" "$WORK" || { say "克隆失败,检查网络"; exit 1; }
cd "$WORK" || exit 1
git remote set-url origin "$REPO_URL"
git config user.name "field-termux"; git config user.email "field@termux.local"
git pull -q origin master 2>/dev/null || true
say "仓库就绪: $(git log --oneline -1 | cut -c1-70)"

# ---------- 1. rish ----------
RISH=""
for c in "$HOME/rish" "$HOME/rish/rish" "$HOME/storage/downloads/rish" \
         "/sdcard/Download/rish" "/storage/emulated/0/Download/rish" "/data/local/tmp/rish"; do
  [ -f "$c" ] && RISH="$c" && break
done
[ -z "$RISH" ] && RISH=$(find "$HOME" -maxdepth 3 -name rish -type f 2>/dev/null | head -1)
[ -z "$RISH" ] && { say "!! 没找到 rish (见 field_auto.sh 第1步安装说明)"; exit 2; }
RISH_DIR=$(dirname "$RISH"); chmod +x "$RISH" 2>/dev/null
RISH_MODE=""
TEST_A=$( (cd "$RISH_DIR" && timeout 30 ./rish "echo RISH_OK_\$(id -u)") 2>&1 )
printf '%s' "$TEST_A" | grep -q "RISH_OK_" && RISH_MODE=args
if [ -z "$RISH_MODE" ]; then
  TEST_B=$( (cd "$RISH_DIR" && echo 'echo RISH_OK_$(id -u)' | timeout 30 ./rish) 2>&1 )
  printf '%s' "$TEST_B" | grep -q "RISH_OK_" && RISH_MODE=stdin
fi
[ -z "$RISH_MODE" ] && { say "$SHIZUKU_DEAD_HINT"; exit 2; }
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

# ---------- 2. 设备现状 ----------
DEST="$WORK/logs_raw/r11_recollect_${RUN_TS}"
mkdir -p "$DEST"
{ echo "# 重收集时间 $RUN_TS"
  rsh "date; cat /proc/sys/kernel/random/boot_id; getenforce; cat /proc/uptime" 30
} > "$DEST/device_state.txt" 2>&1
LSLINE=$(rsh "ls -la /data/local/tmp/R11.out" 30 | tr -d '\r')
echo "$LSLINE" > "$DEST/R11_ls.txt"
say "设备上 R11.out: $LSLINE"
case "$LSLINE" in
  *" 1932 "*) say "字节数仍是 1932 — panic 轮原始文件未被覆盖" ;;
  *R11.out*) say "!! 字节数不是 1932 — 文件可能已被改写 (照收不误)" ;;
  *) say "!! R11.out 不存在了" ;;
esac

# ---------- 3. 校验式收集 (修 v1 的空读误判) ----------
collect(){ local rf="$1" lf="$2" i sz got crs
  for i in 1 2 3 4 5 6; do
    sz=$(rsh "wc -c < '$rf'" 30 | tr -d '\r\n ')
    case "$sz" in ''|*[!0-9]*) say "wc 读数失败, 重试 $i"; sleep 8; continue;; esac
    rsh "cat '$rf'" 90 > "$lf" 2>/dev/null
    [ -s "$lf" ] || { say "cat 返回空 (闪断), 重试 $i"; sleep 8; continue; }
    got=$(wc -c < "$lf" | tr -d ' ')
    crs=$(tr -dc '\r' < "$lf" | wc -c | tr -d ' ')
    if [ "$((got - crs))" = "$sz" ]; then
      say "字节校验通过: ${sz} 字节"; return 0
    fi
    say "字节不符 (设备${sz} 本地$((got - crs))), 重试 $i"; sleep 8
  done
  return 1; }
collect "/data/local/tmp/R11.out" "$DEST/R11.out" \
  || say "!! R11.out 六次没收全 — 把本屏幕输出发给评审"

# ---------- 4. 摘要 ----------
if [ -s "$DEST/R11.out" ]; then
  say "R11.out ($(wc -l < "$DEST/R11.out") 行) 关键行:"
  grep -a "mt61: pselect window\|mt28c: perf task\|mt39: cred_cand\|mt33: child pid\|mt40: task=\|mt48: PTR\|mt28m: cred write\|pselect returned\|mt19b: sched\|mt25: futex" "$DEST/R11.out" | head -12 | sed 's/^/  /'
  say "--- 最后 6 行:"
  tail -6 "$DEST/R11.out" | sed 's/^/  /'
fi

# ---------- 5. 回传 ----------
say "第5步: 回传"
git add -A >/dev/null 2>&1
git commit -q -m "R11 recollect ${RUN_TS}: byte-verified R11.out re-pull (prev recovery flaked: 1B of 1932B; first rsh after boot returned empty and was misjudged success). R11 = panic round: stage-R write landed on child real_cred@task+0x778, selinux_task_to_inode NULL-security crash — this file carries the mt48 PTR line (stage/pc/right) = landing geometry conviction artifact" || true
for i in 1 2 3; do
  git pull -q --rebase origin master 2>/dev/null
  git push -q origin master 2>/dev/null && { PUSHED=1; break; }
  say "推送重试 $i..."; sleep 10
done
command -v termux-wake-unlock >/dev/null 2>&1 && termux-wake-unlock 2>/dev/null
say "=========================================="
if [ "$PUSHED" = 1 ]; then
  say "完成! R11.out 已推回 gitee"
  say "重要: 等评审下一张卡之前, 别跑 field_auto.sh (会覆盖证据/复燃 panic)"
else
  say "推送失败! 把 \$HOME 下最新日志发给评审"
fi
