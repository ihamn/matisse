#!/system/bin/sh
# Deploy mt70 preload.so to /data/local/tmp with SHA256 verification.
# Requires rish/Shizuku running. Usage: bash termux/deploy_mt70.sh
WORK="$HOME/matisse"
RISH="$HOME/rish"
SHA_EXP=$(grep -a '^SHA256 preload.so:' "$WORK/bin/mt70/BUILD_INFO.txt" | awk '{print $3}')
if [ -z "$SHA_EXP" ]; then echo "!! cannot read expected SHA"; exit 1; fi
"$RISH" "rm -f /data/local/tmp/preload.new" 20 >/dev/null 2>&1 || true
"$RISH" "cat > /data/local/tmp/preload.new" < "$WORK/bin/mt70/preload.so" 2>/dev/null || {
  echo "!! rish push failed (Shizuku not running?)"; exit 1
}
"$RISH" "mv -f /data/local/tmp/preload.new /data/local/tmp/preload.so; chmod 644 /data/local/tmp/preload.so" 30 >/dev/null 2>&1 || true
SHA_GOT=$("$RISH" "sha256sum /data/local/tmp/preload.so" 30 2>/dev/null | awk '{print $1}')
echo "expected=$SHA_EXP"
echo "got=$SHA_GOT"
[ "$SHA_EXP" = "$SHA_GOT" ] && echo "DEPLOY_OK" || { echo "DEPLOY_FAIL"; exit 1; }
