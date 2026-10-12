# Ball Knowledge

Name the players who were actually on the field. Every NFL team, every season from 2014 on, with a daily lineup and three daily side games.

- **Lineups.** A team and a season, drawn as a formation. Type names (or nicknames) to fill it in.
- **Journeyman.** One player who got around. His teams are the clue.
- **Box Score.** One monster game: the real stat line and the PPR points. Name who did it.
- **Name That Game.** A game or play famous enough to have a name, from any era.

A fan project. Not affiliated with the NFL or any team.

## Run it

```
npm run build        # writes public/index.html
npx serve public     # or open public/index.html
```

The whole site is one static page. `scripts/assemble.mjs` joins `src/page.html` (markup, styles, game code) with `data/data.json` and adds the document head. On Vercel the production address is stamped in automatically, so link previews and copied results carry it. Elsewhere, set `SITE_URL=https://your.site` when building.

Scores and progress are saved in each visitor's own browser. There is no server and no account.

## The data

`data/data.json` is built from [nflverse](https://github.com/nflverse/nflverse-data) releases: snap counts and rosters for lineups, weekly player stats for box scores, and the schedule file for final scores.

```
npm run data         # needs bash, curl and python3; downloads into data/raw/ and rebuilds data/data.json
```

- A lineup is the 11 players with the most offensive snaps, the 11 with the most defensive snaps, plus the kicker and punter, regular season only. On offense that is the quarterback, five linemen, a back, two receivers, a tight end, and whichever skill player played most after that.
- Box Score takes the biggest PPR days since 2014 at each offensive position, plus defensive games with 3.5 or more sacks, three interceptions or two defensive touchdowns.
- `data/nicknames.py` and `data/named.py` are written by hand. Add to them and rebuild. The build checks every named game from the 1999 season on against the schedule file; older ones are not cross-checked.

Re-run `npm run data` during the season to pick up new games.

## Layout

```
src/page.html          the page
data/data.json         built data the page reads
data/build.py          the build, plus nicknames.py and named.py
data/fetch.sh          downloads the nflverse files
scripts/assemble.mjs   page + data -> public/index.html
static/                favicon and link-preview image
```
