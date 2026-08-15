#!/data/data/com.termux/files/usr/bin/bash
# ★ 强制哈希校验部署脚本
# 用法: bash deploy.sh preload_mtk_R9.so
# 必须在 rish shell 内执行！

set -e

SO_FILE="$1"
if [ -z "$SO_FILE" ]; then
    echo "用法: deploy.sh <preload_mtk_RXX.so>"
    exit 1
fi

SRC="/sdcard/Documents/matisse_backup_essentials/$SO_FILE"
DST="/data/local/tmp/preload.so"

# ── 1. 计算源文件哈希 ──
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  部署: $SO_FILE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━"
SRC_HASH=$(sha256sum "$SRC" | awk '{print $1}')
echo "  源文件 SHA256: $SRC_HASH"
echo "  源文件 大小:   $(stat -c%s "$SRC") bytes"

# ── 2. 先删旧文件（防止 cp 不覆盖） ──
echo ""
echo "  → rm -f $DST"
rm -f "$DST"

# ── 3. 复制 ──
echo "  → cp $SRC $DST"
cp "$SRC" "$DST"

# ── 4. 立刻同步 ──
sync

# ── 5. 验证目标哈希 ★ 关键！ ──
sleep 0.2
DST_HASH=$(sha256sum "$DST" | awk '{print $1}')
DST_SIZE=$(stat -c%s "$DST")

echo ""
echo "  ┌─────────────────────────────────────┐"
if [ "$SRC_HASH" = "$DST_HASH" ] && [ "$DST_SIZE" -gt 1000 ] && [ "$DST_HASH" != "7b2eedbcfa54c1405eb0242a60b64c4290b799d436988b45b5e6715251d230d9" ]; then
    echo "  │  ✅ 部署验证通过!                   │"
    echo "  │  SHA256: ${DST_HASH:0:16}...       │"
    echo "  └─────────────────────────────────────┘"
else
    echo "  │  ❌ 部署验证失败!!!                  │"
    echo "  │  源: ${SRC_HASH:0:16}...            │"
    echo "  │  目: ${DST_HASH:0:16}...            │"
    echo "  │  大小: $DST_SIZE bytes              │"
    echo "  └─────────────────────────────────────┘"
    echo ""
    echo "  ⚠️ 文件可能是全零垃圾！终止运行！"
    # 再试一次
    echo "  → 重试: sync && cp ..."
    sync
    rm -f "$DST"
    cp "$SRC" "$DST"
    sync
    sleep 0.2
    DST_HASH=$(sha256sum "$DST" | awk '{print $1}')
    if [ "$SRC_HASH" != "$DST_HASH" ]; then
        echo "  ❌ 重试仍然失败！请检查 Shizuku/rish 状态"
        exit 1
    fi
    echo "  ✅ 重试成功"
fi

echo ""
echo "  准备就绪，可以运行:"
echo "  LD_PRELOAD=$DST /system/bin/sleep 10"
