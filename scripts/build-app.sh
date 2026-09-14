#!/bin/zsh
# Builds build/Cozy Folders.app from the Swift package.
#
#   scripts/build-app.sh                                   release build, ad-hoc signed
#   SIGN_IDENTITY="Developer ID Application: …" scripts/build-app.sh
set -euo pipefail
cd "$(dirname "$0")/.."

CONFIG=${CONFIG:-release}
APP="build/Cozy Folders.app"
IDENTITY=${SIGN_IDENTITY:--}

swift build -c "$CONFIG" --product CozyFolders
swift build -c "$CONFIG" --product knit-preview
BIN_DIR="$(swift build -c "$CONFIG" --show-bin-path)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/CozyFolders" "$APP/Contents/MacOS/CozyFolders"
cp Resources/Info.plist "$APP/Contents/Info.plist"

# The app icon is a knitted folder, rendered by the same code that knits your folders.
ICONSET="$(mktemp -d)/AppIcon.iconset"
"$BIN_DIR/knit-preview" iconset "$ICONSET"
iconutil --convert icns "$ICONSET" --output "$APP/Contents/Resources/AppIcon.icns"

if [[ "$IDENTITY" == "-" ]]; then
  codesign --force --sign - "$APP"
else
  codesign --force --options runtime --timestamp --sign "$IDENTITY" "$APP"
fi
codesign --verify "$APP"
echo "Built $APP"
