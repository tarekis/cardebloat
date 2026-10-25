#!/usr/bin/env bash
# Read-only survey of the head unit over ADB. Changes nothing on the device.
# Usage: scripts/recon.sh [adb-serial-or-ip:port]
set -euo pipefail

if [[ $# -ge 1 ]]; then
  [[ "$1" == *:* ]] && adb connect "$1" >/dev/null
  export ANDROID_SERIAL="$1"
fi

out="recon/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$out"
sh() { adb shell "$@" 2>&1 || true; }

echo "[*] device: $(adb get-state) $(sh getprop ro.product.model)"

sh getprop                              > "$out/getprop.txt"
sh id                                   > "$out/id.txt"
sh uname -a                             > "$out/uname.txt"
sh cat /proc/cpuinfo                    > "$out/cpuinfo.txt"
sh cat /proc/partitions                 > "$out/partitions.txt"
sh ls -l /dev/block/by-name /dev/block/platform/*/by-name > "$out/by-name.txt"
sh pm list packages -f -U               > "$out/packages-all.txt"
sh pm list packages -s                  > "$out/packages-system.txt"
sh pm list packages -3                  > "$out/packages-user.txt"
sh pm list packages -d                  > "$out/packages-disabled.txt"
sh dumpsys meminfo                      > "$out/meminfo.txt"
sh dumpsys activity services            > "$out/services.txt"
sh dumpsys usb                          > "$out/usb.txt"
sh dumpsys battery                      > "$out/battery.txt"
sh cmd package query-activities -a android.intent.action.MAIN -c android.intent.category.HOME \
                                        > "$out/launchers.txt"
sh top -b -n 1                          > "$out/top.txt"
sh which su                             > "$out/su.txt"
adb logcat -d -b all                    > "$out/logcat.txt" 2>&1 || true
adb logcat -d -b crash                  > "$out/logcat-crash.txt" 2>&1 || true

{
  echo "build.type   = $(sh getprop ro.build.type)"
  echo "debuggable   = $(sh getprop ro.debuggable)"
  echo "secure       = $(sh getprop ro.secure)"
  echo "abi          = $(sh getprop ro.product.cpu.abilist)"
  echo "sdk          = $(sh getprop ro.build.version.sdk)"
  echo "verifiedboot = $(sh getprop ro.boot.verifiedbootstate)"
  echo "flash.locked = $(sh getprop ro.boot.flash.locked)"
  echo "shell id     = $(cat "$out/id.txt")"
  echo "su           = $(cat "$out/su.txt")"
  echo "packages     = $(wc -l < "$out/packages-all.txt") total, $(wc -l < "$out/packages-user.txt") user"
} | tee "$out/summary.txt"

echo "[*] saved to $out/"
