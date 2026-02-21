#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

if [ ! -d .git ]; then
  echo "Kein Git-Repository gefunden in: $ROOT_DIR" >&2
  exit 1
fi

BRANCH="${1:-$(git rev-parse --abbrev-ref HEAD)}"
if [ -z "$BRANCH" ] || [ "$BRANCH" = "HEAD" ]; then
  BRANCH="main"
fi

echo "== Update source from origin/$BRANCH =="
git fetch origin "$BRANCH"
git pull --ff-only origin "$BRANCH"

echo "== Build + install app =="
"$ROOT_DIR/scripts/build_app.sh"

echo "Update complete: /Applications/Basselefant.app"
