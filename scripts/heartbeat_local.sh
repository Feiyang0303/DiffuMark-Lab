#!/usr/bin/env bash
# Local stand-in for the GitHub Action: maybe commit today (often skip), then you push.
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
BEFORE=$(git rev-parse HEAD)
./scripts/daily_log.sh --maybe-commit
AFTER=$(git rev-parse HEAD)
if [ "$BEFORE" = "$AFTER" ]; then
  exit 0
fi
echo "Committed. Run: git push"
