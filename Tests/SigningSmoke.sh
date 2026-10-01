#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
first="${1:-.build/xcode/Build/Products/Debug/HappaTools.app}"
second="${2:-.build/xcode/Build/Products/Release/HappaTools.app}"
certificate_directory="$(mktemp -d "$PWD/.build/signing-smoke.XXXXXX")"
trap 'rm -rf "$certificate_directory"' EXIT
for app in "$first" "$second"; do
  codesign --verify --deep --strict "$app"
  codesign -d --extract-certificates="$certificate_directory/certificate-" "$app"
  security verify-cert -c "$certificate_directory/certificate-0" -c "$certificate_directory/certificate-1" \
    -r "$certificate_directory/certificate-2" -p codeSign -R ocsp -R require
done
targets=(
  ""
  "/Contents/Frameworks/HappaToolsShared.framework"
  "/Contents/PlugIns/FinderSyncExtension.appex"
  "/Contents/Helpers/HappaTools README.app"
  "/Contents/Helpers/HappaTools README.app/Contents/Frameworks/HappaToolsShared.framework"
  "/Contents/Helpers/HappaTools README.app/Contents/PlugIns/ReadmeFinderSyncExtension.appex"
)
for target in "${targets[@]}"; do
  for pair in 0 1; do
    source="$first$target"
    destination="$second$target"
    if [[ "$pair" == 1 ]]; then source="$second$target"; destination="$first$target"; fi
    requirement="$(codesign -d -r- "$source" 2>&1)"
    requirement="${requirement##*designated => }"
    if [[ "$requirement" != *'anchor apple'* || "$requirement" == *'cdhash'* ]]; then
      echo "签名身份必须由 Apple 证书确认且不绑定当前二进制 hash：$source" >&2
      exit 1
    fi
    codesign --verify --strict -R "=$requirement" "$destination"
  done
done
echo '签名检查通过：两个构建的主应用、helper、扩展及 framework 互相满足指定要求。'
