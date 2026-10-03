# Git Reset & Single-Repo Setup

This guide helps you remove any nested Git repositories (like `RealityKitContent/.git`), re-initialize a single clean Git repository at the top level, and optionally connect it to GitHub.

---

## If the helper script is missing
If running `./scripts/reset_git.sh` fails with “No such file or directory”, you are probably not at the project root or the script folder was not created yet.

- First, navigate to your project root (the folder that contains the Xcode project and subfolders like `RealityKitContent`).
- If needed, create the `scripts` folder and the script file locally:

```bash
mkdir -p scripts
cat > scripts/reset_git.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

# reset_git.sh — Remove any Git metadata (including nested), init fresh repo, first commit, set main.
MSG=${1:-"Initial commit"}

# 0) Start from current directory (assumed project root)
ROOT_DIR=$(pwd)
echo "Project root: $ROOT_DIR"

# 1) Remove top-level .git (if present)
if [ -d .git ]; then
  echo "Removing top-level .git..."
  rm -rf .git
fi

# 2) Remove any nested .git directories
FOUND=$(find . -type d -name .git)
if [ -n "$FOUND" ]; then
  echo "Removing nested .git directories:"
  echo "$FOUND"
  # shellcheck disable=SC2086
  rm -rf $FOUND
else
  echo "No nested .git directories found."
fi

# 3) Initialize fresh repo and commit
git init

# Ensure a basic .gitignore exists (keep your own if already present)
if [ ! -f .gitignore ]; then
  cat > .gitignore <<'GITIGNORE'
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
fi

echo "Adding files..."
git add .

echo "Committing..."
git commit -m "$MSG" || true

echo "Setting main as default branch..."
git branch -M main || true

echo "Done. To connect to GitHub run:"
echo "  git remote add origin https://github.com/USER/REPO.git"
echo "  git push -u origin main"
EOF

chmod +x scripts/reset_git.sh
