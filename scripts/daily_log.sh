#!/usr/bin/env bash
# Append one line to logs/daily.md. Optional probabilistic commits.
#
# Usage:
#   ./scripts/daily_log.sh ["optional note"]
#   ./scripts/daily_log.sh --maybe-commit ["optional note"]     # cron: often skip, sometimes 1–3 commits today
#   ./scripts/daily_log.sh --random-dated-commits [days] ["note"]  # backfill past N days (default 365)
#   ./scripts/daily_log.sh --dry-run --random-dated-commits 30   # preview only
#
# Tunables (env):
#   DAILY_LOG_RANDOM_DAYS=365
#   DAILY_LOG_SKIP_P=0.52        # P(no commits on a given day) when backfilling
#   DAILY_LOG_BUSY_P=0.08        # P(a "green" day with several commits)
#   DAILY_LOG_MAYBE_SKIP_P=0.48  # P(skip entirely) for --maybe-commit
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOG_DIR="$ROOT/logs"
LOG="$LOG_DIR/daily.md"
DRY_RUN=0

mkdir -p "$LOG_DIR"
if [[ ! -f "$LOG" ]]; then
  echo "# Daily log" > "$LOG"
  echo "" >> "$LOG"
  echo "Run \`./scripts/daily_log.sh\` with an optional message; the GitHub Action may also append via --maybe-commit." >> "$LOG"
  echo "" >> "$LOG"
fi

cd "$ROOT" || exit 1
SHA=$(git rev-parse --short HEAD 2>/dev/null || echo "?")
LINE=$(git log -1 --oneline 2>/dev/null || echo "not a git repo or no commits")
BR=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "?")

_commit_messages=(
  "chore: daily log"
  "chore: notes"
  "chore: update log"
  "chore: checkpoint"
  "chore: sync notes"
)

_random_commit_message() {
  local i=$((RANDOM % ${#_commit_messages[@]}))
  echo "${_commit_messages[$i]}"
}

_append_log_line() {
  local day="$1" time="$2" msg="$3"
  if [[ -n "$msg" ]]; then
    echo "- **$day** $time · \`$SHA\` $BR — $LINE — *$msg*" >> "$LOG"
  else
    echo "- **$day** $time · \`$SHA\` $BR — $LINE" >> "$LOG"
  fi
}

_do_commit() {
  local git_date="$1" label="$2"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "[dry-run] would commit at $git_date ($label)"
    return 0
  fi
  export GIT_AUTHOR_DATE="$git_date"
  export GIT_COMMITTER_DATE="$git_date"
  git add -f "$LOG"
  if git diff --staged --quiet; then
    echo "Nothing staged (unexpected)." >&2
    exit 1
  fi
  git commit -m "$(_random_commit_message)"
}

# Prints one line per planned commit: DAY<TAB>TIME<TAB>GIT_DATE
_plan_natural_day_commits() {
  local days="${1:-365}"
  local skip_p="${DAILY_LOG_SKIP_P:-0.52}"
  local busy_p="${DAILY_LOG_BUSY_P:-0.08}"
  python3 - "$days" "$skip_p" "$busy_p" <<'PY'
import random
import sys
from datetime import datetime, timedelta, timezone

days = int(sys.argv[1])
skip_p = float(sys.argv[2])
busy_p = float(sys.argv[3])
light_p = 1.0 - skip_p - busy_p
if light_p < 0:
    raise SystemExit("DAILY_LOG_SKIP_P + DAILY_LOG_BUSY_P must be <= 1")

today = datetime.now(timezone.utc).date()
start = today - timedelta(days=days - 1)

for offset in range(days):
    day = start + timedelta(days=offset)
    roll = random.random()
    if roll < skip_p:
        continue
    if roll < skip_p + light_p:
        n = random.randint(1, 2)
    elif roll < skip_p + light_p + busy_p:
        n = random.randint(3, 6)
    else:
        n = random.randint(7, 11)

    used_minutes = set()
    for _ in range(n):
        while True:
            minute = random.randint(9 * 60, 22 * 60 + 59)
            if minute not in used_minutes:
                used_minutes.add(minute)
                break
        hour, minute_of_hour = divmod(minute, 60)
        second = random.randint(0, 59)
        dt = datetime(
            day.year, day.month, day.day, hour, minute_of_hour, second, tzinfo=timezone.utc
        )
        git_d = dt.strftime("%Y-%m-%d %H:%M:%S") + " +0000"
        print(f"{day.isoformat()}\t{dt.strftime('%H:%M')}\t{git_d}")
PY
}

_plan_maybe_today_commits() {
  local skip_p="${DAILY_LOG_MAYBE_SKIP_P:-0.48}"
  python3 - "$skip_p" <<'PY'
import random
import sys
from datetime import datetime, timezone

skip_p = float(sys.argv[1])
roll = random.random()
if roll < skip_p:
    raise SystemExit(0)

if roll < skip_p + 0.40:
    n = 1
elif roll < skip_p + 0.40 + 0.42:
    n = 2
else:
    n = random.randint(3, 4)

today = datetime.now(timezone.utc).date()
used_minutes = set()
for _ in range(n):
    while True:
        minute = random.randint(9 * 60, 22 * 60 + 59)
        if minute not in used_minutes:
            used_minutes.add(minute)
            break
    hour, minute_of_hour = divmod(minute, 60)
    second = random.randint(0, 59)
    dt = datetime(
        today.year, today.month, today.day, hour, minute_of_hour, second, tzinfo=timezone.utc
    )
    git_d = dt.strftime("%Y-%m-%d %H:%M:%S") + " +0000"
    print(f"{today.isoformat()}\t{dt.strftime('%H:%M')}\t{git_d}")
PY
}

_run_planned_commits() {
  local note="$1"
  local label="$2"
  local count=0
  while IFS=$'\t' read -r day time git_date; do
    [[ -z "$day" ]] && continue
    _append_log_line "$day" "$time" "$note"
    _do_commit "$git_date" "$label"
    count=$((count + 1))
  done
  if [[ "$count" -eq 0 ]]; then
    if [[ "$DRY_RUN" -eq 1 ]]; then
      echo "[dry-run] no commits planned"
    else
      echo "No commit today (random skip)."
    fi
    exit 0
  fi
  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "[dry-run] planned $count commit(s)"
  else
    echo "Created $count commit(s). Push when ready: git push"
  fi
}

if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=1
  shift
fi

if [[ "${1:-}" == "--maybe-commit" ]]; then
  shift
  MSG="${*:-}"
  _run_planned_commits "$MSG" "maybe" < <(_plan_maybe_today_commits)
  exit 0
fi

if [[ "${1:-}" == "--random-dated-commits" ]]; then
  shift
  DAYS="${DAILY_LOG_RANDOM_DAYS:-365}"
  if [[ "${1:-}" =~ ^[0-9]+$ ]]; then
    DAYS="$1"
    shift
  fi
  MSG="${*:-}"
  PLAN="$(_plan_natural_day_commits "$DAYS")"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "[dry-run] backfill over $DAYS day(s) (skip_p=${DAILY_LOG_SKIP_P:-0.52}, busy_p=${DAILY_LOG_BUSY_P:-0.08})"
    echo "$PLAN" | awk -F'\t' -v days="$DAYS" '
      { c[$1]++ }
      END {
        active = 0
        for (d in c) {
          active++
          if (c[d] >= 7) green++
          else if (c[d] >= 3) med++
          else light++
        }
        empty = days - active
        printf "[dry-run] active=%d empty=%d light=%d medium=%d green=%d total_commits=%d\n",
          active, empty, light+0, med+0, green+0, NR
      }'
  fi
  _run_planned_commits "$MSG" "backfill" <<< "$PLAN"
  exit 0
fi

DAY=$(date +%Y-%m-%d)
TIME=$(date '+%H:%M')
MSG="${*:-}"
if [[ -n "$MSG" ]]; then
  _append_log_line "$DAY" "$TIME" "$MSG"
else
  _append_log_line "$DAY" "$TIME" ""
fi
echo "Appended: $LOG"
