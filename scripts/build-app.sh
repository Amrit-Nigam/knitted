#!/bin/zsh
# Builds build/Cozy Borders.app from the Swift package.
#
#   scripts/build-app.sh            release build, ad-hoc signed
#   SIGN_IDENTITY="Developer ID Application: …" scripts/build-app.sh
#
# Accessibility grants are tied to the code signature. With ad-hoc signing every rebuild
# looks like a new app to macOS, so you'll need to re-grant access (remove the old entry in
# System Settings › Privacy & Security › Accessibility, then add the new build). A stable
# signing identity avoids that.
set -euo pipefail
cd "$(dirname "$0")/.."

CONFIG=${CONFIG:-release}
APP="build/Cozy Borders.app"
IDENTITY=${SIGN_IDENTITY:--}

swift build -c "$CONFIG" --product CozyBorders
BIN="$(swift build -c "$CONFIG" --show-bin-path)/CozyBorders"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/CozyBorders"
cp Resources/Info.plist "$APP/Contents/Info.plist"

if [[ "$IDENTITY" == "-" ]]; then
  codesign --force --sign - "$APP"
else
  codesign --force --options runtime --timestamp --sign "$IDENTITY" "$APP"
fi
codesign --verify --verbose "$APP"
echo "Built $APP"
