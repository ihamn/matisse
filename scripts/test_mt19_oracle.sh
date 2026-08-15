#!/system/bin/sh
# mt19: SLIDE 真触发 oracle — 同线程 overlay + 10-word 表 + 未映射 tree_pc
SRC=/sdcard/Documents/matisse_backup_essentials/preload_mt19_slidetrigger.so
DST=/data/local/tmp/preload.so
RUNLOG=/data/local/tmp/mt19_run.out
LOG=/sdcard/Documents/matisse_backup_essentials/logs/mt19_oracle.txt

echo "=== [1/5] 部署 ==="
rm -f $DST; cp $SRC $DST; sync
SRC_H=$(sha256sum $SRC | awk '{print $1}')
DST_H=$(sha256sum $DST | awk '{print $1}')
[ "$SRC_H" = "$DST_H" ] || { echo "HASH MISMATCH"; exit 1; }
echo "HASH OK"

echo "=== [2/5] am kill-all ==="
am kill-all 2>&1 | tail -1
echo "boot_before=$(cat /proc/sys/kernel/random/boot_id)" > $LOG

echo "=== [3/5] 运行 (SLIDE trigger + 未映射 tree_pc, 180s 上限) ==="
rm -f $RUNLOG
timeout 180 env \
  PSELECT_SLIDE_TRIGGER=1 \
  PSELECT_TREE_PC=ffffffb0fffffff8 \
  PSELECT_TREE_LEFT=0 \
  PSELECT_SHIFT=0 \
  PSELECT_SKIP_WARMUP=1 \
  LD_PRELOAD=$DST /system/bin/sleep 120 > $RUNLOG 2>&1
RC=$?
echo "run_rc=$RC" >> $LOG
cat $RUNLOG >> $LOG
echo "=== [4/5] boot_id 后 ==="
echo "boot_after=$(cat /proc/sys/kernel/random/boot_id)" >> $LOG
echo "=== DONE ===" >> $LOG
