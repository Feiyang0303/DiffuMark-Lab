# Daily activity log

## Manual log (`daily.md`)

From the repo root:

```bash
./scripts/daily_log.sh
./scripts/daily_log.sh "optional one-line note"
```

Appends a row to `daily.md` with date, time, tip commit, branch, and last message.

## Automated daily commits (GitHub Action)

`.github/workflows/daily_heartbeat.yml` runs once per day and calls
`./scripts/daily_log.sh --maybe-commit`, which is **intentionally random**:

| Outcome | Approx. chance | Commits that day |
|--------|----------------|------------------|
| Skip | ~48% | 0 |
| Light | ~40% | 1 |
| Medium | ~10% | 2 |
| Green | ~2% | 3–4 |

Commit times are scattered through the day. Messages vary (`chore: notes`, etc.).

**Setup for contribution graph credit:**

1. Repo → **Settings → Secrets and variables → Actions → New repository secret**
2. Name: `HEARTBEAT_GIT_EMAIL`
3. Value: an email **verified** on your GitHub account

Without that secret, commits are attributed to `github-actions[bot]` and usually do **not** count on your graph.

**Try it:** **Actions → Daily heartbeat → Run workflow**.

**Local:** `./scripts/heartbeat_local.sh` then `git push`.

## Backfill past days (natural gaps + green days)

```bash
./scripts/daily_log.sh --dry-run --random-dated-commits 90   # preview
./scripts/daily_log.sh --random-dated-commits 365            # write commits
git push
```

Defaults: ~52% empty days, occasional medium/green days. Override with
`DAILY_LOG_SKIP_P` / `DAILY_LOG_BUSY_P`.
