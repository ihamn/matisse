#!/data/data/com.termux/files/usr/bin/bash
set -u
[ "$(wc -c < "$0")" = 4131 ] || { echo "[r11v2] 粘贴不完整(得$(wc -c < "$0")字节应4131), 把这行屏幕发评审, 别重跑"; exit 9; }
say(){ echo "[r11v2] $*"; }
command -v termux-wake-lock >/dev/null 2>&1 && termux-wake-lock 2>/dev/null
W="$HOME/matisse"
T=$(cat "$HOME/.matisse_token" 2>/dev/null | tr -d ' \r\n')
U="https://ihamn:${T}@gitee.com/ihamn/matisse.git"
cd "$W" || { say "没有 $W 仓库目录"; exit 1; }
git remote set-url origin "$U"
git config user.name "field-termux"; git config user.email "field@termux.local"
git pull -q origin master 2>/dev/null || true
D="$W/logs_raw/r11v2_$(date +%Y%m%d_%H%M%S)"; mkdir -p "$D"
RF=/data/local/tmp/R11.out
R=""
for c in "$HOME/rish" "$HOME/rish/rish" "$HOME/storage/downloads/rish" /sdcard/Download/rish /data/local/tmp/rish; do [ -f "$c" ] && R="$c" && break; done
[ -z "$R" ] && { say "没找到 rish"; exit 2; }
RD=$(dirname "$R"); M=""
(cd "$RD" && timeout 25 ./rish "echo OK_" 2>/dev/null) | grep -q "OK_" && M=args
[ -z "$M" ] && { echo 'echo OK_' | (cd "$RD" && timeout 25 ./rish 2>/dev/null) | grep -q "OK_" && M=stdin; }
[ -z "$M" ] && { say "Shizuku 连不上: Termux和Shizuku省电策略改无限制, 亮屏插电后重跑"; exit 2; }
say "rish 就绪 模式 $M"
rsh(){ local c="$1" t="${2:-90}" o i
 for i in 1 2 3 4; do
  if [ "$M" = args ]; then o=$( (cd "$RD" && timeout "$t" ./rish "$c") 2>&1 )
  else o=$( (cd "$RD" && printf '%s\n' "$c" | timeout "$t" ./rish) 2>&1 ); fi
  printf '%s' "$o" | grep -q "Request timeout\|blocked by your system" || { printf '%s\n' "$o"; return 0; }
  say "闪断重试 $i"; sleep 8
 done; printf '%s\n' "$o"; }
LS=$(rsh "ls -la $RF" 30 | tr -d '\r'); echo "$LS" > "$D/R11_ls.txt"; say "$LS"
SZ=$(rsh "wc -c < $RF" 30 | tr -d '\r\n ')
case "$SZ" in ''|*[!0-9]*) say "读不到文件, 发屏幕给评审"; exit 3;; esac
MD=$(rsh "md5sum $RF" 30 | tr -d '\r' | cut -d' ' -f1)
echo "$MD" > "$D/R11_device_md5.txt"
say "设备: ${SZ}字节 md5=${MD:-无}"
B=$(rsh "base64 $RF" 120 | tr -d '\r\n ')
printf '%s' "$B" | base64 -d > "$D/R11.out" 2>/dev/null
OK=0
if [ "$(wc -c < "$D/R11.out" | tr -d ' ')" = "$SZ" ]; then
  if [ -z "$MD" ] || [ "$(md5sum "$D/R11.out" | cut -d' ' -f1)" = "$MD" ]; then OK=1; fi
fi
[ "$OK" = 1 ] && say "OK base64 通道通过 ${SZ}字节 md5一致"
if [ "$OK" = 0 ]; then
  say "整发不符(本地$(wc -c < "$D/R11.out" | tr -d ' ')字节), od-hex 兜底..."
  H=$(rsh "od -An -v -tx1 $RF" 120 | tr -d '\r\n ')
  if [ -n "$H" ] && [ "${#H}" = "$((SZ*2))" ]; then
    : > "$D/R11.out"; k=0
    while [ "$k" -lt "${#H}" ]; do printf "\x${H:$k:2}" >> "$D/R11.out"; k=$((k+2)); done
    [ "$(wc -c < "$D/R11.out" | tr -d ' ')" = "$SZ" ] && OK=1 && say "OK od-hex 兜底通过"
  fi
fi
[ "$OK" = 1 ] || say "!! 两条通道都没收全 — 发屏幕给评审"
if [ -s "$D/R11.out" ]; then
  NN=$(od -An -v -tx1 "$D/R11.out" | tr -s ' ' '\n' | grep -c '^00$')
  say "体检: ${SZ}字节 / NUL ${NN} / 行数 $(wc -l < "$D/R11.out")"
  [ "$NN" -ge $((SZ-4)) ] && say "!! 基本全NUL — panic轮日志没落闪存, 这就是结论, 已完整回传"
  say "--- 前64字节:"; head -c 64 "$D/R11.out" | od -Ax -tx1z | sed 's/^/  /'
  say "--- 关键行:"; grep -a "mt48:\|mt55\|mt61:\|mt40:\|mt28m\|PTR\|spray\|page_base" "$D/R11.out" | head -15 | sed 's/^/  /'
  say "--- 最后6行:"; tail -6 "$D/R11.out" | sed 's/^/  /'
fi
cp "$0" "$W/termux/recollect_r11_v2.sh" 2>/dev/null
git add -A; git commit -qm "R11 recollect v2 base64 ${D##*/}: read-only zero fire, md5 verified, NUL census, self-published" || true
P=0
for i in 1 2 3; do git pull -q --rebase origin master 2>/dev/null; git push -q origin master 2>/dev/null && { P=1; break; }; say "推送重试 $i"; sleep 8; done
command -v termux-wake-unlock >/dev/null 2>&1 && termux-wake-unlock 2>/dev/null
if [ "$P" = 1 ]; then say "完成已推回. 以后一行: cd ~/matisse && git pull -q && bash termux/recollect_r11_v2.sh"; else say "推送失败, 数据在 $D, 发屏幕给评审"; fi
say "纪律: 等下一张卡前别跑 field_auto.sh"
say "MARKER_R11V2_DONE 脚本完整执行到底"
