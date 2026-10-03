#!/usr/bin/env bash
set -euo pipefail
MSG=${1:-"Initial commit"}
[ -d .git ] && rm -rf .git
FOUND=$(find . -type d -name .git)
[ -n "$FOUND" ] && rm -rf $FOUND || true
git init
[ -f .gitignore ] || cat > .gitignore <<'GITIGNORE'
# macOS
.DS_Store

# Xcode
DerivedData/
build/
xcuserdata/

# SPM
.build/
.swiftpm/
GITIGNORE
git add .
git commit -m "$MSG" || true
git branch -M main || true
echo "Done. To connect:"
echo "  git remote add origin https://github.com/USER/REPO.git"
echo "  git push -u origin main"
