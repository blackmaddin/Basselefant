#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="Basselefant"
APP_PATH="${1:-$ROOT_DIR/dist/${APP_NAME}.app}"
DMG_ROOT="$ROOT_DIR/dist/.dmg-root"
DMG_PATH="$ROOT_DIR/dist/${APP_NAME}.dmg"

if [ ! -d "$APP_PATH" ]; then
  echo "App bundle nicht gefunden: $APP_PATH" >&2
  echo "Bitte zuerst ./scripts/build_app.sh ausfuehren." >&2
  exit 1
fi

rm -rf "$DMG_ROOT" "$DMG_PATH"
mkdir -p "$DMG_ROOT"
cp -R "$APP_PATH" "$DMG_ROOT/${APP_NAME}.app"
ln -s /Applications "$DMG_ROOT/Applications"

hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$DMG_ROOT" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

rm -rf "$DMG_ROOT"
echo "Created DMG: $DMG_PATH"
