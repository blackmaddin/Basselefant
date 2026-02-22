#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/iOSApp/BasselefantiOS.xcodeproj"
DERIVED_PATH="$ROOT_DIR/.build/ios-derived"
HOME_PATH="$ROOT_DIR/.build/ios-home"

if [ -d /Applications/Xcode.app/Contents/Developer ]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi

mkdir -p "$DERIVED_PATH" "$HOME_PATH"

HOME="$HOME_PATH" xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme BasselefantiOS \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  -derivedDataPath "$DERIVED_PATH" \
  CODE_SIGNING_ALLOWED=NO \
  build

echo "Built: $DERIVED_PATH/Build/Products/Debug-iphoneos/BasselefantiOS.app"
echo "Zum Installieren auf iPhone in Xcode Team/Signing setzen und auf dein Geraet starten."
