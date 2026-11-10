#!/usr/bin/env bash
# Builds KinVault.app into ./build, signed ad hoc with the sandbox entitlements.
# Usage: scripts/build-app.sh [--zip] [--dmg]
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

for option in "$@"; do
  case "$option" in
    --zip)
      rm -f build/KinVault.zip
      ditto -c -k --keepParent "$APP" build/KinVault.zip
      echo "Zipped build/KinVault.zip"
      ;;
    --dmg)
      STAGE="$(mktemp -d)"
      cp -R "$APP" "$STAGE/KinVault.app"
      ln -s /Applications "$STAGE/Applications"
      rm -f build/KinVault.dmg
      hdiutil create -quiet -volname "KinVault" -srcfolder "$STAGE" -format UDZO build/KinVault.dmg
      rm -rf "$STAGE"
      echo "Packaged build/KinVault.dmg"
      ;;
    *)
      echo "Unknown option: $option" >&2
      exit 1
      ;;
  esac
done
