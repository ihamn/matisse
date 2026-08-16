#!/system/bin/sh
# mt47-diag: EACCES 60秒判别 — 在与失败运行【完全相同的启动器】里执行
# 判别什么: open(/proc/child/mem) 的 EACCES 来自哪条检查
#
# 用法: 把本脚本推到设备, 在你 10:35/10:53 跑 mt47 的【同一个入口】执行:
#   rish -c 'sh /data/local/tmp/diag_eacces_60s.sh'    (或其他你用的方式)
# 结果直接对照文末判读表。
LOG=/data/local/tmp/diag_eacces.out
{
echo "=== 1. 启动器身份 ==="
id
echo "uid=$(id -u) euid=$(id -u)"
echo "self_domain=$(cat /proc/self/attr/current 2>/dev/null)"
echo "enforce=$(getenforce 2>/dev/null)"
echo "ptrace_scope=$(cat /proc/sys/kernel/yama/ptrace_scope 2>/dev/null || echo 'no yama')"
echo "modules_disabled=$(cat /proc/sys/kernel/modules_disabled 2>/dev/null)"

echo ""
echo "=== 2. dd 判别: open 拒绝 vs 读错误 ==="
sleep 30 & CPID=$!
sleep 1
echo "-- child pid=$CPID domain=$(cat /proc/$CPID/attr/current 2>/dev/null)"
dd if=/proc/$CPID/mem bs=1 count=1 2>&1 | head -3
echo "-- dd exit=$?"
echo "-- 对比: 自己的 mem"
dd if=/proc/self/mem bs=1 count=1 2>&1 | head -2
echo "-- 对比: dd 到一个有效地址 (maps 第一行)"
MAP=$(grep -m1 "r..p" /proc/$CPID/maps | cut -d- -f1)
echo "addr=$MAP"
dd if=/proc/$CPID/mem bs=1 count=1 skip=$((0x$MAP)) 2>&1 | head -3
kill $CPID 2>/dev/null

echo ""
echo "=== 3. root 语境检查 (如果 dd 报 Permission denied) ==="
echo "capsh 不可用就手读: CapEff 含 bit19(CAP_SYS_PTRACE)=0x80000?"
grep -E "CapEff|CapPrm" /proc/self/status

echo "=== DONE ==="
} > $LOG 2>&1
cat $LOG
echo ""
echo "(结果也存 $LOG)"
#
# ==================== 判读表 ====================
# A. dd 报 "Permission denied" 且 self_domain != u:r:shell:s0
#    → 启动器语境错了 (Termux=untrusted_app 或其他域, 域内无 process ptrace 权限)
#    → 处置: 换回上午的启动方式 (Shizuku rish / adb shell), 不用改代码
#
# B. dd 报 "Permission denied" 且 self_domain == u:r:shell:s0
#    → shell 域被策略收紧? 但上午 shell 能开 → 说明有持久状态变化
#    → 处置: 对比上午/下午 dmesg 里的 avc denial, 上传 pstore
#
# C. dd 报 "Input/output error" (而不是 Permission denied)
#    → open 是成功的! EACCES 另有其因 (例如特定子进程域转换)
#    → 处置: 跑重建后的 .so, 看 mt47-diag 打印的具体 pid/域
#
# D. modules_disabled=1
#    → 任务2相关: insmod 会 EPERM, 与 EACCES 无关但会挡终局
# ================================
