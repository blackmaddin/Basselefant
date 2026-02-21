#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="Basselefant"
BIN_NAME="BasselefantApp"
APP_DIR="$ROOT_DIR/dist/${APP_NAME}.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
BIN_PATH="$ROOT_DIR/.build/release/$BIN_NAME"
INSTALL_TARGET="/Applications/${APP_NAME}.app"

cd "$ROOT_DIR"

echo "== Build release binary =="
swift build -c release

echo "== Generate icon =="
if [ ! -x "$ROOT_DIR/.build/debug/IconGenerator" ]; then
  swift build --product IconGenerator
fi
"$ROOT_DIR/.build/debug/IconGenerator"

echo "== Assemble app bundle =="
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$BIN_PATH" "$MACOS_DIR/$APP_NAME"
cp "dist/AppIcon.png" "$RESOURCES_DIR/AppIcon.png"
chmod +x "$MACOS_DIR/$APP_NAME"

cat > "$CONTENTS_DIR/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Basselefant</string>
  <key>CFBundleDisplayName</key><string>Basselefant</string>
  <key>CFBundleIdentifier</key><string>com.basselefant.visualizer</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleExecutable</key><string>Basselefant</string>
  <key>CFBundleIconFile</key><string>AppIcon.png</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>NSMicrophoneUsageDescription</key>
  <string>Basselefant benoetigt Mikrofonzugriff, um Musik live zu erkennen und zu visualisieren.</string>
  <key>NSAppleEventsUsageDescription</key>
  <string>Basselefant liest den aktuell wiedergegebenen Track aus Music.app oder Spotify.</string>
</dict>
</plist>
PLIST

echo "== Codesign (ad-hoc) =="
codesign --force --deep --sign - "$APP_DIR"

echo "== Install to /Applications =="
rm -rf "$INSTALL_TARGET"
cp -R "$APP_DIR" "$INSTALL_TARGET"

echo "Installed: $INSTALL_TARGET"
