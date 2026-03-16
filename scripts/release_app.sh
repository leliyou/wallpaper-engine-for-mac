#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="Wallpaper Prototype.app"
APP_DIR="$ROOT_DIR/dist/$APP_NAME"
ZIP_PATH="$ROOT_DIR/dist/Wallpaper-Prototype-macOS.zip"
DMG_PATH="$ROOT_DIR/dist/Wallpaper-Prototype-macOS.dmg"
ENTITLEMENTS_PATH="$ROOT_DIR/Packaging/entitlements.plist"

DEVELOPER_ID_APP="${DEVELOPER_ID_APP:-}"
NOTARY_PROFILE="${NOTARY_PROFILE:-}"
SKIP_NOTARIZATION="${SKIP_NOTARIZATION:-0}"

cd "$ROOT_DIR"

zsh "$ROOT_DIR/scripts/package_app.sh"

if [[ -n "$DEVELOPER_ID_APP" ]]; then
  echo "Applying Developer ID signature: $DEVELOPER_ID_APP"
  codesign --force --deep --options runtime --entitlements "$ENTITLEMENTS_PATH" --sign "$DEVELOPER_ID_APP" "$APP_DIR"
  codesign --verify --deep --strict "$APP_DIR"

  rm -f "$ZIP_PATH"
  ditto -c -k --sequesterRsrc --keepParent "$APP_DIR" "$ZIP_PATH"
else
  echo "DEVELOPER_ID_APP not set. Keeping ad-hoc signature only."
fi

if [[ "$SKIP_NOTARIZATION" == "1" ]]; then
  echo "Skipping notarization because SKIP_NOTARIZATION=1"
  exit 0
fi

if [[ -z "$DEVELOPER_ID_APP" || -z "$NOTARY_PROFILE" ]]; then
  echo "Skipping notarization. Set DEVELOPER_ID_APP and NOTARY_PROFILE to continue."
  exit 0
fi

echo "Submitting zip to Apple notarization service..."
xcrun notarytool submit "$ZIP_PATH" --keychain-profile "$NOTARY_PROFILE" --wait

echo "Stapling ticket to app bundle..."
xcrun stapler staple "$APP_DIR"
xcrun stapler validate "$APP_DIR"

rm -f "$ZIP_PATH"
ditto -c -k --sequesterRsrc --keepParent "$APP_DIR" "$ZIP_PATH"
zsh "$ROOT_DIR/scripts/package_dmg.sh"

echo "Release artifacts ready:"
echo "  App: $APP_DIR"
echo "  Zip: $ZIP_PATH"
echo "  DMG: $DMG_PATH"
