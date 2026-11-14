#!/bin/bash
# Copies Murph's own art into App/Resources/LocalArt (gitignored), resized for the app.
# The app works without any of it: every slot falls back to team colors and plain rows.
#
#   logos/<TEAM>.png        team mark, shown wherever a team is named
#   modes/<mode>.jpg        cover art: daily, journeyman, boxscore, namedgame
#   players/<key>.jpg       shown when that player is the revealed answer
#   games/<key>.jpg         shown when that named game is the revealed answer
#
# <key> is the name as the game types it: lowercase letters and digits only
# ("T.J. Watt" -> tjwatt, "The Tuck Rule Game" -> thetuckrulegame, "28–3" -> 283).
#
# Usage: ios/scripts/sync-art.sh [source folder]   (default: ~/Documents/ball knowledge)
set -euo pipefail

SRC="${1:-$HOME/Documents/ball knowledge}"
HERE="$(cd "$(dirname "$0")" && pwd)"
DST="$HERE/../App/Resources/LocalArt"
[ -d "$SRC" ] || { echo "no art folder at $SRC"; exit 0; }

rm -rf "$DST"
mkdir -p "$DST/logos" "$DST/modes" "$DST/players" "$DST/games"

photo() { # photo <source> <dest.jpg> <max side>
  [ -f "$SRC/$1" ] || { echo "  missing  $1"; return 0; }
  sips -s format jpeg -s formatOptions 85 -Z "$3" "$SRC/$1" --out "$DST/$2" >/dev/null
  echo "  $2  <-  $1"
}

echo "logos"
LOGOS="$SRC/NFL-Logos-Individual-PNGs"
# The Washington file is the mark retired in 2020; the game leaves that name out for those
# seasons, so Washington keeps its color mark until a current logo is supplied.
while read -r num code; do
  f=$(ls "$LOGOS"/"$num"-*.png 2>/dev/null | head -1 || true)
  [ -n "$f" ] || { echo "  missing  $num ($code)"; continue; }
  sips -Z 512 "$f" --out "$DST/logos/$code.png" >/dev/null
done <<'EOF'
01 ARI
02 ATL
03 BAL
04 BUF
05 CAR
06 CHI
07 CIN
08 CLE
09 DAL
10 DEN
11 DET
12 GB
13 HOU
14 IND
15 JAX
16 KC
17 MIA
18 MIN
19 NE
20 NO
21 NYG
22 NYJ
23 LAR
24 LV
25 PHI
26 PIT
27 SF
28 LAC
29 SEA
30 TB
31 TEN
EOF
echo "  $(ls "$DST/logos" | wc -l | tr -d ' ') team logos"

echo "modes"
photo "journeyman.png"        "modes/journeyman.jpg" 1400
photo "games-with-names.png"  "modes/namedgame.jpg"  1400
photo "hurts.jpeg"            "modes/boxscore.jpg"   1400

echo "players"
photo "brady.jpeg"   "players/tombrady.jpg"   1200
photo "hurts.jpeg"   "players/jalenhurts.jpg" 1200
photo "tj-watt.jpeg" "players/tjwatt.jpg"     1200

echo "games"
# Photos first; the illustrated collage panels below replace them where both exist.
photo "tuck rule.png" "games/thetuckrulegame.jpg" 1200
photo "28-3.png"      "games/283.jpg"             1200
# Each collage is six games, left to right, top to bottom. "-" is a panel whose game is not in the data.
[ -f "$SRC/games-with-names.png" ] && swift "$HERE/crop-panels.swift" "$SRC/games-with-names.png" "$DST/games" \
  thetuckrulegame 283 thecatch thehelmetcatch theicebowl thephillyspecial
[ -f "$SRC/more-games.png" ] && swift "$HERE/crop-panels.swift" "$SRC/more-games.png" "$DST/games" \
  thegreatestgameeverplayed theimmaculatereception - oneyardshort - theminneapolismiracle

# Anything in the source folder this script does not know about yet.
KNOWN="more-games.png journeyman.png games-with-names.png hurts.jpeg brady.jpeg tj-watt.jpeg tuck rule.png 28-3.png logos.jpeg nfl.png"
echo "not placed yet"
find "$SRC" -maxdepth 1 -type f ! -name ".*" | while read -r f; do
  b="$(basename "$f")"
  case " $KNOWN " in *" $b "*) ;; *) echo "  $b" ;; esac
done
du -sh "$DST" | awk '{print "total " $1}'
