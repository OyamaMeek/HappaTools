#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
configuration="${1:-Debug}"
if [[ "$configuration" != Debug && "$configuration" != Release ]]; then
  echo "Usage: bash scripts/build.sh [Debug|Release]" >&2
  exit 2
fi
signing_identity="${CODE_SIGN_IDENTITY:-}"
if [[ -z "$signing_identity" ]]; then
  signing_identity="$(security find-identity -v -p codesigning | awk '/"Apple Development:/ && !/CSSMERR/ { print $2; exit }')"
  if [[ -z "$signing_identity" ]]; then
    signing_identity="-"
  fi
fi
if [[ "$signing_identity" == "-" ]]; then
  echo '未使用证书签名：每次更新可能重新请求隐私权限。请配置 Apple Development 证书或 CODE_SIGN_IDENTITY。' >&2
fi
xcodebuild -project HappaTools.xcodeproj -scheme HappaTools \
  -configuration "$configuration" -derivedDataPath .build/xcode \
  -destination 'generic/platform=macOS' CODE_SIGNING_ALLOWED=NO build
app=".build/xcode/Build/Products/$configuration/HappaTools.app"
helper="$app/Contents/Helpers/HappaTools README.app"
for host in "$helper" "$app"; do
  for library in "$host"/Contents/MacOS/*.dylib "$host"/Contents/PlugIns/*.appex/Contents/MacOS/*.dylib; do
    if [[ -f "$library" ]]; then codesign --force --sign "$signing_identity" "$library"; fi
  done
  codesign --force --sign "$signing_identity" "$host/Contents/Frameworks/HappaToolsShared.framework"
  for extension in "$host"/Contents/PlugIns/*.appex; do
    codesign --force --sign "$signing_identity" --entitlements FinderSyncExtension/FinderSyncExtension.entitlements "$extension"
  done
  if [[ "$host" == "$helper" ]]; then
    codesign --force --sign "$signing_identity" --entitlements FinderSyncExtension/FinderSyncExtension.entitlements "$host"
  fi
done
codesign --force --sign "$signing_identity" --entitlements HappaTools/HappaTools.entitlements "$app"
codesign --verify --deep --strict "$app"
if [[ "$signing_identity" != "-" ]]; then
  certificate_directory="$(mktemp -d "$PWD/.build/signing.XXXXXX")"
  trap 'rm -rf "$certificate_directory"' EXIT
  codesign -d --extract-certificates="$certificate_directory/certificate-" "$app"
  if ! security verify-cert -c "$certificate_directory/certificate-0" -c "$certificate_directory/certificate-1" \
    -r "$certificate_directory/certificate-2" -p codeSign -R ocsp -R require; then
    echo '签名证书未通过 Apple 信任及吊销检查；请在 Xcode 更新证书，不要安装此产物。' >&2
    exit 1
  fi
fi
echo "本机开发构建：${app}（签名身份：${signing_identity}，未公证）"
