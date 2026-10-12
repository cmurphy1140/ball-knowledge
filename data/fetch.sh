#!/usr/bin/env bash
# Download the nflverse files the data build reads, into data/raw/. Re-run during the season to refresh.
set -euo pipefail
cd "$(dirname "$0")"
BASE=https://github.com/nflverse/nflverse-data/releases/download
FIRST=2014
LAST=${1:-$(date +%Y)}
mkdir -p raw/snaps raw/rosters raw/players raw/stats raw/sched
for y in $(seq "$FIRST" "$LAST"); do
  curl -fsSL -o "raw/snaps/snap_counts_$y.csv" "$BASE/snap_counts/snap_counts_$y.csv"
  curl -fsSL -o "raw/rosters/roster_$y.csv" "$BASE/rosters/roster_$y.csv"
  curl -fsSL -o "raw/stats/week_$y.csv" "$BASE/stats_player/stats_player_week_$y.csv"
done
curl -fsSL -o raw/players/players.csv "$BASE/players/players.csv"
curl -fsSL -o raw/sched/games.csv "$BASE/schedules/games.csv"
echo "Fetched $FIRST-$LAST into data/raw/"
