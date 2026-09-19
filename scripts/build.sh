#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
configuration="${1:-Debug}"
if [[ "$configuration" != Debug && "$configuration" != Release ]]; then
  echo "Usage: bash scripts/build.sh [Debug|Release]" >&2
  exit 2
fi
xcodebuild -project HappaTools.xcodeproj -scheme HappaTools \
  -configuration "$configuration" -derivedDataPath .build/xcode \
  -destination 'generic/platform=macOS' CODE_SIGNING_ALLOWED=NO build
app=".build/xcode/Build/Products/$configuration/HappaTools.app"
helper="$app/Contents/Helpers/HappaTools README.app"
for host in "$helper" "$app"; do
  for library in "$host"/Contents/MacOS/*.dylib "$host"/Contents/PlugIns/*.appex/Contents/MacOS/*.dylib; do
    if [[ -f "$library" ]]; then codesign --force --sign - "$library"; fi
  done
  codesign --force --sign - "$host/Contents/Frameworks/HappaToolsShared.framework"
  for extension in "$host"/Contents/PlugIns/*.appex; do
    codesign --force --sign - --entitlements FinderSyncExtension/FinderSyncExtension.entitlements "$extension"
  done
  if [[ "$host" == "$helper" ]]; then
    codesign --force --sign - --entitlements FinderSyncExtension/FinderSyncExtension.entitlements "$host"
  fi
done
codesign --force --sign - --entitlements HappaTools/HappaTools.entitlements "$app"
codesign --verify --deep --strict "$app"
echo "本机开发构建：${app}（临时签名，未公证）"
