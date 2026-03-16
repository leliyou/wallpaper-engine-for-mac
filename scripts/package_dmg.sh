#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="Wallpaper Prototype.app"
APP_DIR="$ROOT_DIR/dist/$APP_NAME"
DMG_NAME="Wallpaper-Prototype-macOS.dmg"
DMG_PATH="$ROOT_DIR/dist/$DMG_NAME"
STAGING_DIR="$ROOT_DIR/dist/dmg-staging"

cd "$ROOT_DIR"

if [[ ! -d "$APP_DIR" ]]; then
  zsh "$ROOT_DIR/scripts/package_app.sh"
fi

rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"

cp -R "$APP_DIR" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

rm -f "$DMG_PATH"
hdiutil create \
  -volname "Wallpaper Prototype" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

rm -rf "$STAGING_DIR"

echo "Packaged dmg at: $DMG_PATH"
