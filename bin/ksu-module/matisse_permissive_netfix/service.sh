#!/system/bin/sh
# Matisse Permissive + NetFix - KernelSU module service
# Runs in ksu domain (has security:setenforce). KernelSU/ksud flips SELinux
# back to Enforcing after boot-completed -> su socket AVC denied + network dies.
# This keeps enforce=0 and repairs network once after boot.
MODDIR=${0%/*}
LOG="$MODDIR/service.log"
echo "=== matisse_permissive_netfix start $(date) uid=$(id -u) ===" > "$LOG"
getenforce >> "$LOG" 2>&1
fix_network() {
  resetprop ro.boot.flash.locked 0 2>>"$LOG"
  resetprop ro.boot.verifiedbootstate green 2>>"$LOG"
  resetprop ro.boot.warranty_bit 0 2>>"$LOG"
  resetprop ro.warranty_bit 0 2>>"$LOG"
  setprop ctl.restart netd 2>>"$LOG"
  /system/bin/svc wifi enable 2>>"$LOG"
  /system/bin/svc data enable 2>>"$LOG"
  echo "network fix done $(date)" >> "$LOG"
}
i=0
while true; do
  i=$((i + 1))
  cur=$(cat /sys/fs/selinux/enforce 2>/dev/null)
  if [ "$cur" != "0" ]; then
    echo 0 > /sys/fs/selinux/enforce 2>>"$LOG"
    echo "setenforce 0 @iter=$i" >> "$LOG"
  fi
  if [ "$i" = "5" ]; then fix_network; fi
  sleep 2
done
