#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
bash scripts/build.sh Release
mkdir -p dist
stage="$(mktemp -d "$PWD/dist/package.XXXXXX")"
trap 'rm -rf "$stage"' EXIT
ditto .build/xcode/Build/Products/Release/HappaTools.app "$stage/HappaTools.app"
ln -s /Applications "$stage/Applications"
cp docs/SETUP.md "$stage/使用说明.md"
hdiutil create -volname HappaTools -srcfolder "$stage" -ov -format UDZO dist/HappaTools-local.dmg
echo 'dist/HappaTools-local.dmg 是本机开发包，未进行 Developer ID 签名或公证。'
