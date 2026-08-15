#!/system/bin/sh
# aristotle v1 测试脚本 — 单次 rish 调用完成 部署+验证+运行+存档
# 用法 (rish 内): sh /sdcard/Documents/matisse_backup_essentials/scripts/test_aristotle_v1.sh
set -x
SRC=/sdcard/Documents/matisse_backup_essentials/preload_mt10.so
DST=/data/local/tmp/preload.so
LOG=/sdcard/Documents/matisse_backup_essentials/logs/mt10_test1.txt

echo "=== [1/4] 部署 ==="
rm -f $DST
cp $SRC $DST
sync
SRC_H=$(sha256sum $SRC | awk '{print $1}')
DST_H=$(sha256sum $DST | awk '{print $1}')
echo "src=$SRC_H dst=$DST_H"
[ "$SRC_H" = "$DST_H" ] || { echo "❌ 哈希不一致，拒绝运行"; exit 1; }
echo "✅ 哈希一致"

echo "=== [2/4] 运行 exploit (sleep 30) ==="
LD_PRELOAD=$DST /system/bin/sleep 30 2>&1 | tee $LOG
echo "preload exit=$?"

echo "=== [2.5/4] SELinux 状态验证 ==="
getenforce 2>&1 | tee -a $LOG
echo "=== [3/4] 检查 su daemon ==="
ls -la /data/local/tmp/su 2>&1
if [ -x /data/local/tmp/su ]; then
  echo "=== [4/4] su -c id ==="
  /data/local/tmp/su -c id 2>&1 | tee -a $LOG
else
  echo "su daemon 未安装"
fi
echo "=== DONE ==="
