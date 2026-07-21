#!/bin/bash
# Rasterizes icons for the quick local `swift build` / build-app.sh dev path.
# The real shipped icon (masked, shadowed, Liquid Glass treatment) comes from
# Resources/AppIcon.icon via Xcode's own build (see project.yml) — this
# script instead pulls the same flat source artwork straight out of that
# Icon Composer document and produces an unmasked, dev-only .icns from it, so
# local test builds stay visually in sync without a second source of truth.
# Uses `sips`, which renders images/SVGs directly at the requested size
# (unlike `qlmanage -t`, which pads/positions inconsistently).
set -euo pipefail
cd "$(dirname "$0")/.."

APP_ICON_SOURCE="Resources/AppIcon.icon/Assets/AppIcon.png"
MENU_SVG="Resources/SourceIcons/skrivbord-menu-bar-icon.svg"
ICONSET="Resources/AppIcon.iconset"

rm -rf "$ICONSET"
mkdir -p "$ICONSET"

render() {
  local src="$1" size="$2" out="$3"
  sips -s format png -Z "$size" "$src" --out "$out" >/dev/null
}

render "$APP_ICON_SOURCE" 16   "$ICONSET/icon_16x16.png"
render "$APP_ICON_SOURCE" 32   "$ICONSET/icon_16x16@2x.png"
render "$APP_ICON_SOURCE" 32   "$ICONSET/icon_32x32.png"
render "$APP_ICON_SOURCE" 64   "$ICONSET/icon_32x32@2x.png"
render "$APP_ICON_SOURCE" 128  "$ICONSET/icon_128x128.png"
render "$APP_ICON_SOURCE" 256  "$ICONSET/icon_128x128@2x.png"
render "$APP_ICON_SOURCE" 256  "$ICONSET/icon_256x256.png"
render "$APP_ICON_SOURCE" 512  "$ICONSET/icon_256x256@2x.png"
render "$APP_ICON_SOURCE" 512  "$ICONSET/icon_512x512.png"
render "$APP_ICON_SOURCE" 1024 "$ICONSET/icon_512x512@2x.png"

iconutil -c icns "$ICONSET" -o "Resources/AppIcon.icns"
rm -rf "$ICONSET"

render "$MENU_SVG" 22 "Resources/MenuBarIcon.png"
render "$MENU_SVG" 44 "Resources/MenuBarIcon@2x.png"

echo "Generated Resources/AppIcon.icns (unmasked, dev-only), Resources/MenuBarIcon.png, Resources/MenuBarIcon@2x.png"
