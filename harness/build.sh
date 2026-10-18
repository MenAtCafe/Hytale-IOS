#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

OUT="$PWD/harness/out"
APP="$OUT/GLProbe.app"
TARGET="arm64-apple-ios17.0-simulator"
mkdir -p "$OUT/modulecache" "$OUT/clangcache" "$OUT/tmp" "$APP"

echo "== dispatch table"
python3 harness/gen/emit_switch.py

echo "== libHytaleGL.dylib"
xcrun --sdk iphonesimulator clang -target "$TARGET" -c gate4/loader.c -o "$OUT/loader.o"
TMPDIR="$OUT/tmp" xcrun --sdk iphonesimulator swiftc \
  -target "$TARGET" -parse-as-library -whole-module-optimization \
  -emit-library -module-name HytaleGL \
  -module-cache-path "$OUT/modulecache" \
  -Xcc "-fmodules-cache-path=$OUT/clangcache" \
  -Xlinker -install_name -Xlinker @rpath/libHytaleGL.dylib \
  -o "$OUT/libHytaleGL.dylib" \
  slice/app/GLShim.swift gate4/HUD.swift gate4/ShaderSources.swift gate4/HytaleGL.swift \
  "$OUT/GLProcSwitch.generated.swift" "$OUT/loader.o"

echo "== manifest"
python3 harness/manifest/gen_manifest.py --dylib "$OUT/libHytaleGL.dylib"

echo "== GLProbe.app"
TMPDIR="$OUT/tmp" xcrun --sdk iphonesimulator swiftc \
  -target "$TARGET" -module-name GLProbe \
  -module-cache-path "$OUT/modulecache" \
  -Xcc "-fmodules-cache-path=$OUT/clangcache" \
  -o "$APP/GLProbe" \
  harness/probe/main.swift harness/probe/AppDelegate.swift \
  harness/probe/ProbeViewController.swift harness/probe/SceneDelegate.swift \
  harness/probe/Bootstrap.swift \
  harness/probe/GLAPI.swift harness/probe/Probe.swift \
  "$OUT/Manifest.generated.swift"

cp "$OUT/libHytaleGL.dylib" "$APP/"
cp harness/vendor/SDL3.dylib "$APP/"
cp harness/probe/Info.plist "$APP/Info.plist"
codesign --force --deep --sign - "$APP" >/dev/null
echo "built $APP"
