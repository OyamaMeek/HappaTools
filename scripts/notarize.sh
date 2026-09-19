#!/bin/bash
set -euo pipefail
if [[ $# != 2 ]]; then
  echo 'Usage: bash scripts/notarize.sh /absolute/path/HappaTools.app KEYCHAIN_PROFILE' >&2
  exit 2
fi
app="$1"
profile="$2"
if [[ "$app" != /* || ! -d "$app/Contents" ]]; then
  echo '需要已使用 Developer ID 签名的 .app 绝对路径' >&2
  exit 2
fi
codesign --verify --deep --strict "$app"
embedded=(
  "$app"
  "$app/Contents/Frameworks/HappaToolsShared.framework"
  "$app/Contents/PlugIns/FinderSyncExtension.appex"
  "$app/Contents/Helpers/HappaTools README.app"
  "$app/Contents/Helpers/HappaTools README.app/Contents/Frameworks/HappaToolsShared.framework"
  "$app/Contents/Helpers/HappaTools README.app/Contents/PlugIns/ReadmeFinderSyncExtension.appex"
)
for target in "${embedded[@]}"; do
  signature="$(codesign -dv --verbose=4 "$target" 2>&1)"
  if [[ "$signature" != *'Authority=Developer ID Application:'* || "$signature" != *'runtime'* ]]; then
    echo "嵌套项目必须使用 Developer ID Application 证书和 Hardened Runtime 签名：$target" >&2
    exit 1
  fi
done
cd "$(dirname "$0")/.."
mkdir -p dist
ditto -c -k --keepParent "$app" dist/HappaTools-notarization.zip
xcrun notarytool submit dist/HappaTools-notarization.zip --keychain-profile "$profile" --wait
xcrun stapler staple "$app"
xcrun stapler validate "$app"
spctl --assess --type execute --verbose "$app"
echo '应用已通过公证验证；请使用该已装订应用制作分发 DMG。'
