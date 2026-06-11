#!/usr/bin/env bash
# Optional: append a line to logs/heartbeat.log (gitignored; local only).
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
mkdir -p logs
echo "$(date -u -Iseconds)Z heartbeat (local)" >> logs/heartbeat.log
echo "Appended to logs/heartbeat.log"
