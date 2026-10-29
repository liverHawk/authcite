#!/bin/sh
set -e

# Merge dev into main while strictly excluding samples/

CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)

if [ "$CURRENT_BRANCH" != "main" ]; then
  echo "Switching to main branch..."
  git checkout main
fi

echo "Merging dev into main (preparing commit)..."
# Perform merge without committing automatically
git merge --no-commit --no-ff dev

# Remove samples/ from stage and working tree on main
if git ls-files --error-unmatch samples >/dev/null 2>&1 || [ -d samples ]; then
  echo "Excluding samples/ from main..."
  git rm -r --cached samples 2>/dev/null || true
  rm -rf samples
fi

# Restore main branch .gitignore
git checkout HEAD -- .gitignore 2>/dev/null || true

# Check if there are changes to commit
if git diff --cached --quiet; then
  echo "No changes to commit. main is up-to-date with dev."
else
  git commit -m "Merge branch 'dev' into main (excluding samples/)"
  echo "Successfully merged dev into main without samples/!"
fi

