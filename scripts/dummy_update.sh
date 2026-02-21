#!/bin/zsh
set -euo pipefail

REPO_URL="https://github.com/blackmaddin/Basselefant.git"
BRANCH="main"
REPO_DIR="$HOME/.basselefant/repo"

if [ ! -d "$REPO_DIR/.git" ]; then
  mkdir -p "$(dirname "$REPO_DIR")"
  git clone "$REPO_URL" "$REPO_DIR"
fi

cd "$REPO_DIR"
git fetch origin "$BRANCH"
git pull --ff-only origin "$BRANCH"
"$REPO_DIR/scripts/build_app.sh"

echo "Update complete: /Applications/Basselefant.app"
