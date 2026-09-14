#!/bin/zsh
# Builds a universal Knitted.app and packs it into build/Knitted-<version>.dmg
# (the app plus an Applications shortcut to drag it onto). Upload the DMG to a GitHub Release.
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Resources/Info.plist)
DMG="build/Knitted-$VERSION.dmg"

UNIVERSAL=1 scripts/build-app.sh

STAGING="$(mktemp -d)/Knitted"
mkdir -p "$STAGING"
cp -R build/Knitted.app "$STAGING/"
ln -s /Applications "$STAGING/Applications"

rm -f "$DMG"
hdiutil create -volname "Knitted" -srcfolder "$STAGING" -fs HFS+ -format UDZO -ov "$DMG"
rm -rf "$(dirname "$STAGING")"

shasum -a 256 "$DMG"
echo "Built $DMG"
