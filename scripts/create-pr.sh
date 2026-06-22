#!/usr/bin/env bash
set -euo pipefail

# Helper: commit changes and create a PR against main
# Usage: run from repository root after files are updated

TODAY="$(date +%Y-%m-%d)"
BRANCH=${CI_BRANCH_NAME:-"claude/daily-report-$TODAY-$(date +%s)"}

git checkout -b "$BRANCH"

git add resources/seen-products-history.json docs/ .claude/CLAUDE.md || true

if git diff --cached --quiet; then
  echo "Nothing to commit. Exiting."
  exit 0
fi

git commit -m "chore: daily Amazon top-sellers report for $TODAY"

git push --set-upstream origin "$BRANCH"

if command -v gh >/dev/null 2>&1; then
  gh pr create --title "chore: daily Amazon top-sellers report for $TODAY" \
    --body "Auto-generated daily report. Review and merge to main." --base main --head "$BRANCH"
else
  echo "GH CLI not installed. Created branch $BRANCH and pushed to origin. Please open a PR into main manually."
fi
