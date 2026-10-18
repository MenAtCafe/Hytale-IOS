#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
APP="$PWD/harness/out/GLProbe.app"

DEVICE=$(printenv GLPROBE_DEVICE || true)
if [ -z "$DEVICE" ]; then
  DEVICE=$(xcrun simctl list devices available \
    | grep -E '^ +iPhone' | head -1 \
    | sed -E 's/.*\(([0-9A-Fa-f-]{36})\).*/\1/')
fi
[ -n "$DEVICE" ] || { echo "no iPhone simulator found"; exit 1; }

echo "device: $DEVICE"
xcrun simctl boot "$DEVICE" 2>/dev/null || true
xcrun simctl bootstatus "$DEVICE" -b >/dev/null
xcrun simctl install "$DEVICE" "$APP"
DATA=$(xcrun simctl get_app_container "$DEVICE" com.hytale.glprobe data)
REPORT="$DATA/tmp/glprobe/report.json"
rm -f "$REPORT"

echo "launching..."
xcrun simctl launch --terminate-running-process "$DEVICE" com.hytale.glprobe || true

for _ in $(seq 1 20); do
  [ -f "$REPORT" ] && break
  sleep 1
done

if [ -f "$REPORT" ]; then
  cp "$REPORT" harness/out/report.json
  cp "$DATA/tmp/glprobe/frame.png" harness/out/frame.png 2>/dev/null || true
  echo "== report"
  cat "$REPORT"
else
  echo "no report written; recent device log:"
  xcrun simctl spawn "$DEVICE" log show --last 2m --predicate 'process == "GLProbe"' 2>/dev/null | tail -40 || true
  exit 1
fi
