#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
IOS_DIR="$ROOT_DIR/iOSApp"

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "xcodegen ist nicht installiert. Installiere mit: brew install xcodegen" >&2
  exit 1
fi

cd "$IOS_DIR"
xcodegen generate
echo "Generated: $IOS_DIR/BasselefantiOS.xcodeproj"
