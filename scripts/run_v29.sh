#!/system/bin/sh
echo "=== v29 test3 $(date) ==="
echo "binary md5=$(md5sum /data/local/tmp/preload.so)"
echo "---"
LD_PRELOAD=/data/local/tmp/preload.so /system/bin/sleep 10 2>&1
echo "=== exit: $? ==="
