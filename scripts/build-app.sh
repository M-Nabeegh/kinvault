#!/usr/bin/env bash
# Builds KinVault.app into ./build, signed ad hoc with the sandbox entitlements.
# Usage: scripts/build-app.sh [--zip]
set -euo pipefail

cd "$(dirname "$0")/.."
APP="build/KinVault.app"

swift build -c release --arch arm64
BIN="$(swift build -c release --arch arm64 --show-bin-path)/KinVault"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/KinVault"
cp Packaging/Info.plist "$APP/Contents/Info.plist"
cp Packaging/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

codesign --force --sign - --options runtime \
  --entitlements Packaging/KinVault.entitlements "$APP"

echo "Built $APP"

if [[ "${1:-}" == "--zip" ]]; then
  ditto -c -k --keepParent "$APP" build/KinVault.zip
  echo "Zipped build/KinVault.zip"
fi
