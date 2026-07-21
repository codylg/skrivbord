#!/bin/bash
# Builds Skrivbord in release mode and assembles it into a real .app bundle,
# signed with your Apple Development identity (local run/debug signing —
# not the "Apple Distribution" or "Developer ID Application" identities
# needed for App Store submission or notarized distribution to others).
set -euo pipefail
cd "$(dirname "$0")/.."

SIGNING_IDENTITY="Apple Development: clg@clg.name (RMK656G4SM)"

./Scripts/generate-icons.sh

swift build -c release
BIN_PATH="$(swift build -c release --show-bin-path)/Skrivbord"

APP="Skrivbord.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$BIN_PATH" "$APP/Contents/MacOS/Skrivbord"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/"
cp Resources/MenuBarIcon.png "$APP/Contents/Resources/"
cp Resources/MenuBarIcon@2x.png "$APP/Contents/Resources/"

# This dev build has no asset catalog, so Info.plist's CFBundleIconName (used
# by the real Xcode/Icon Composer build) won't resolve — point it at the
# loose .icns above instead, without touching the shared Info.plist.
/usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "$APP/Contents/Info.plist"

codesign --deep --force --options runtime --sign "$SIGNING_IDENTITY" "$APP"

echo "Built $APP, signed as: $SIGNING_IDENTITY"
codesign --display --verbose=2 "$APP" 2>&1 | grep -E "Authority|Identifier|TeamIdentifier"
echo "Move $APP to /Applications for reliable Launch at Login registration."
