import csv, sys, json, collections, re, unicodedata, importlib.util
d, out = sys.argv[1], sys.argv[2]
YEARS = range(2014, 2027)
FR = {"STL": "LAR", "LA": "LAR", "SD": "LAC", "OAK": "LV", "ARZ": "ARI", "BLT": "BAL", "CLV": "CLE", "HST": "HOU", "SL": "LAR"}
def fr(t): return FR.get(t, t)
def norm(s):
    s = unicodedata.normalize("NFKD", s).encode("ascii", "ignore").decode().lower()
    s = re.sub(r"\b(jr|sr|ii|iii|iv|v)\b\.?", "", s)
    return re.sub(r"[^a-z]", "", s)

# ---- player metadata
meta = {}      # pfr_id -> dict
meta_by_name = collections.defaultdict(list)
meta_g = {}
for r in csv.DictReader(open(f"{d}/players/players.csv", encoding="utf-8")):
    m = dict(college=r["college_name"], dy=r["draft_year"], dr=r["draft_round"], dp=r["draft_pick"], dt=r["draft_team"],
             rookie=r["rookie_season"], pos=r["position"], gsis=r["gsis_id"], name=r["display_name"], last=r["last_season"],
             alts=[r["display_name"], r["first_name"] + " " + r["last_name"], r["football_name"] + " " + r["last_name"], r["common_first_name"] + " " + r["last_name"]])
    if r["pfr_id"]: meta[r["pfr_id"]] = m
    if r["gsis_id"]: meta_g[r["gsis_id"]] = m
    meta_by_name[norm(r["display_name"])].append(m)

# ---- rosters: jersey + depth chart position per season/team
jersey = {}    # (season, team, key) -> jersey ; key = pfr id or normalized name
rpos = {}
gsis2pfr = {}
for y in YEARS:
    for r in csv.DictReader(open(f"{d}/rosters/roster_{y}.csv", encoding="utf-8")):
        if r["pfr_id"] and r["gsis_id"]: gsis2pfr[r["gsis_id"]] = r["pfr_id"]
for pid, m in meta.items():
    if m["gsis"]: gsis2pfr.setdefault(m["gsis"], pid)
for y in YEARS:
    for r in csv.DictReader(open(f"{d}/rosters/roster_{y}.csv", encoding="utf-8")):
        t = fr(r["team"])
        keys = [("n", norm(r["full_name"]))]
        pid = r["pfr_id"] or gsis2pfr.get(r["gsis_id"])
        if pid: keys.append(("p", pid))
        for k in keys:
            if r["jersey_number"]: jersey[(y, t, k)] = r["jersey_number"]
            dc = r["depth_chart_position"] or r["position"]
            if dc: rpos[(y, t, k)] = dc
            if r["college"]: rpos[("college", k)] = r["college"]

# ---- snaps
agg = {}   # (season, team, pid) -> dict
games_off = collections.defaultdict(dict); games_def = collections.defaultdict(dict)
career = collections.defaultdict(lambda: collections.defaultdict(int))  # pid -> (season, team) -> snaps
names = {}
firstwk = collections.defaultdict(dict)
for y in YEARS:
    for r in csv.DictReader(open(f"{d}/snaps/snap_counts_{y}.csv", encoding="utf-8")):
        if r["game_type"] != "REG": continue
        t = fr(r["team"]); pid = r["pfr_player_id"] or "n:" + norm(r["player"])
        o, df, st = int(float(r["offense_snaps"] or 0)), int(float(r["defense_snaps"] or 0)), int(float(r["st_snaps"] or 0))
        a = agg.setdefault((y, t, pid), dict(o=0, d=0, st=0, pos=collections.Counter(), g=0))
        a["o"] += o; a["d"] += df; a["st"] += st; a["g"] += 1
        a["pos"][r["position"]] += max(o, df, st, 1)
        names[pid] = r["player"]
        g = r["game_id"]
        games_off[(y, t)][g] = max(games_off[(y, t)].get(g, 0), o)
        games_def[(y, t)][g] = max(games_def[(y, t)].get(g, 0), df)
        career[pid][(y, t)] += o + df + st
        fw = firstwk[pid]; wk = int(r["week"])
        if (y, t) not in fw or wk < fw[(y, t)]: fw[(y, t)] = wk

OLS = {"T", "G", "C", "OL", "OT", "OG", "LT", "RT", "LG", "RG"}
DLS = {"DE", "DT", "NT", "DL"}
LBS = {"LB", "OLB", "ILB", "MLB"}
DBS = {"CB", "S", "FS", "SS", "DB"}
def base(p): return p.split("/")[0].upper() if p else ""
def group(p):
    b = base(p)
    if b == "QB": return "QB"
    if b in ("RB", "HB"): return "RB"
    if b == "FB": return "FB"
    if b == "WR": return "WR"
    if b == "TE": return "TE"
    if b in OLS: return "OL"
    if b in DLS: return "DL"
    if b in LBS: return "LB"
    if b in DBS: return "DB"
    if b in ("K", "P", "LS"): return b
    return "?"
SPEC = {"T": "T", "OT": "T", "LT": "T", "RT": "T", "G": "G", "OG": "G", "LG": "G", "RG": "G", "C": "C",
        "DE": "DE", "DT": "DT", "NT": "NT", "OLB": "OLB", "ILB": "ILB", "MLB": "ILB",
        "CB": "CB", "S": "S", "FS": "S", "SS": "S"}
def roster_lookup(tbl, y, t, pid, name):
    return tbl.get((y, t, ("p", pid))) or tbl.get((y, t, ("n", norm(name))))
def label(y, t, pid, a, grp):
    if grp in ("QB", "RB", "FB", "WR", "TE", "K", "P"): return grp
    # most-used specific label in the snap data for this team-season
    for p, _ in a["pos"].most_common():
        s = SPEC.get(base(p))
        if s and group(s) == grp: return s
    r = roster_lookup(rpos, y, t, pid, names[pid])
    if r and SPEC.get(base(r)) and group(SPEC[base(r)]) == grp: return SPEC[base(r)]
    # the player's other seasons
    c = collections.Counter()
    for (yy, tt, pp), aa in agg.items():
        if pp == pid:
            for p, n in aa["pos"].items():
                s = SPEC.get(base(p))
                if s and group(s) == grp: c[s] += n
    if c: return c.most_common(1)[0][0]
    m = meta.get(pid)
    if m and SPEC.get(base(m["pos"])) and group(SPEC[base(m["pos"])]) == grp: return SPEC[base(m["pos"])]
    return grp

players = {}  # pid -> index
plist = []
def pidx(pid):
    if pid not in players:
        players[pid] = len(plist); plist.append(pid)
    return players[pid]

lineups = {}
issues = []
teams = sorted({t for (y, t) in games_off})
assert len(teams) == 32, teams
for y in YEARS:
    for t in teams:
        tot_o = sum(games_off[(y, t)].values()); tot_d = sum(games_def[(y, t)].values())
        ps = [(pid, a, group(a["pos"].most_common(1)[0][0])) for (yy, tt, pid), a in agg.items() if yy == y and tt == t]
        def top(grps, key, n, excl=()):
            c = [(pid, a, g) for pid, a, g in ps if g in grps and pid not in excl and a[key] > 0]
            c.sort(key=lambda x: -x[1][key]); return c[:n]
        off = top({"QB"}, "o", 1) + top({"RB"}, "o", 1) + top({"WR"}, "o", 2) + top({"TE"}, "o", 1)
        used = {p[0] for p in off}
        off += top({"RB", "FB", "WR", "TE"}, "o", 1, used)
        off += top({"OL"}, "o", 5)
        de = top({"DL", "LB", "DB"}, "d", 11)
        def kp(want):
            c = []
            for pid, a, g in ps:
                if g not in ("K", "P") or a["st"] <= 0: continue
                real = (meta.get(pid) or {}).get("pos") or roster_lookup(rpos, y, t, pid, names[pid]) or g
                if real not in ("K", "P"): real = g
                if real == want: c.append((pid, a, want))
            c.sort(key=lambda x: -x[1]["st"]); return c[:1]
        k = kp("K"); p = kp("P")
        if len(off) != 11 or len(de) != 11 or len(k) != 1 or len(p) != 1:
            issues.append((y, t, len(off), len(de), len(k), len(p)))
        slots = []
        for side, lst, key, tot in (("O", off, "o", tot_o), ("D", de, "d", tot_d), ("S", k + p, "st", 0)):
            for pid, a, g in lst:
                lab = label(y, t, pid, a, g)
                j = roster_lookup(jersey, y, t, pid, names[pid]) or ""
                pct = round(100 * a[key] / tot) if tot else 0
                slots.append([pidx(pid), side, lab, int(j) if j != "" else None, pct, a["g"]])
        lineups[f"{y}{t}"] = slots

# ---- order slots for display
OORD = {"QB": 0, "RB": 1, "FB": 2, "WR": 3, "TE": 4, "T": 5, "G": 6, "C": 7, "OL": 8}
DORD = {"DE": 0, "DT": 1, "NT": 1, "DL": 2, "OLB": 3, "ILB": 4, "LB": 4, "CB": 5, "S": 6, "DB": 7}
for key, slots in lineups.items():
    o = [s for s in slots if s[1] == "O"]; dd = [s for s in slots if s[1] == "D"]; sp = [s for s in slots if s[1] == "S"]
    o.sort(key=lambda s: (OORD.get(s[2], 9), -s[4])); dd.sort(key=lambda s: (DORD.get(s[2], 9), -s[4]))
    lineups[key] = o + dd + sp

# ---- player table
def pmeta(pid):
    m = meta.get(pid)
    nm = names[pid]
    if not m:
        c = meta_by_name.get(norm(nm), [])
        m = c[0] if len(c) == 1 else None
    college = (m or {}).get("college") or rpos.get(("college", ("p", pid))) or rpos.get(("college", ("n", norm(nm)))) or ""
    dy = (m or {}).get("dy") or ""; dp = (m or {}).get("dp") or ""; dr = (m or {}).get("dr") or ""; dt = fr((m or {}).get("dt") or "")
    rookie = (m or {}).get("rookie") or ""
    nm = {"Jackrabbit Jenkins": "Janoris Jenkins", "Evander Hood": "Ziggy Hood", "Ricky Wagner": "Rick Wagner", "Matthew Bosher": "Matt Bosher",
          "Manuel Ramirez": "Manny Ramirez", "Zackary Bowman": "Zack Bowman", "Olabisi Johnson": "Bisi Johnson"}.get(nm, nm)
    college = college.split(";")[0].strip()
    return [nm, college, int(dy) if dy else (int(rookie) if rookie else 0), int(dr) if dr else 0, int(dp) if dp else 0, dt]

# ---- journeyman pool: started (in a lineup) 2+ seasons, 3+ teams in window with real playing time
starts = collections.Counter(); spos = {}
for key, slots in lineups.items():
    for s in slots:
        starts[s[0]] += 1; spos[s[0]] = s[2]
paths = {}
for pid, i in players.items():
    stops = [(y, t) for (y, t), n in sorted(career[pid].items(), key=lambda kv: (kv[0][0], firstwk[pid][kv[0]])) if n >= 40]
    if starts[i] >= 2 and len({t for _, t in stops}) >= 3:
        paths[i] = ",".join(f"{y % 100}{t}" for y, t in stops)

P = [pmeta(pid) for pid in plist]
alias = {}
for pid, i in players.items():
    m = meta.get(pid)
    if not m: continue
    seen = {norm(P[i][0])}; out_a = []
    for a in [names[pid]] + m["alts"]:
        a = a.strip()
        if a and norm(a) not in seen and " " in a:
            seen.add(norm(a)); out_a.append(a)
    if out_a: alias[i] = out_a
# ---- big games: weekly box scores, 2014 on, regular season and playoffs
sched = {r["game_id"]: r for r in csv.DictReader(open(f"{d}/sched/games.csv", encoding="utf-8"))}
pfr2gsis = {v: k for k, v in gsis2pfr.items()}
extra = {}
def stat_idx(r):
    g = r["player_id"]; pid = gsis2pfr.get(g)
    if pid in players: return players[pid]
    if g in extra: return extra[g]
    m = meta_g.get(g)
    nm = (m or {}).get("name") or r["player_display_name"]
    for cand in by_name_idx.get(norm(nm), []):
        if not m or P[cand][1].lower() == (m.get("college") or "").split(";")[0].strip().lower(): return cand
    college = ((m or {}).get("college") or "").split(";")[0].strip()
    dy = (m or {}).get("dy") or ""; rook = (m or {}).get("rookie") or ""
    P.append([nm, college, int(dy) if dy else (int(rook) if rook else 0), int((m or {}).get("dr") or 0), int((m or {}).get("dp") or 0), fr((m or {}).get("dt") or "")])
    i = len(P) - 1; extra[g] = i
    spos[i] = SPEC.get(base(r["position"]), {"HB": "RB", "FB": "FB"}.get(r["position"], r["position"]))
    if m:
        seen = {norm(nm)}; al = []
        for a_ in m["alts"]:
            a_ = a_.strip()
            if a_ and norm(a_) not in seen and " " in a_: seen.add(norm(a_)); al.append(a_)
        if al: alias[i] = al
    return i
by_name_idx = collections.defaultdict(list)
for i, x in enumerate(P): by_name_idx[norm(x[0])].append(i)
def fnum(r, k):
    v = r.get(k) or ""
    return float(v) if v not in ("", "NA") else 0.0
def nice(v): return str(int(v)) if float(v).is_integer() else ("%.1f" % v)
GT = {"REG": "REG", "WC": "WC", "DIV": "DIV", "CON": "CON", "SB": "SB"}
def statline(r, grp):
    L_ = []
    g = lambda k: fnum(r, k)
    if grp == "QB":
        L_ += [["CMP/ATT", "%d/%d" % (g("completions"), g("attempts"))], ["PASS YDS", nice(g("passing_yards"))], ["PASS TD", nice(g("passing_tds"))], ["INT", nice(g("passing_interceptions"))]]
        if g("carries") >= 4 or g("rushing_tds") > 0: L_ += [["RUSH YDS", nice(g("rushing_yards"))]] + ([["RUSH TD", nice(g("rushing_tds"))]] if g("rushing_tds") else [])
        if g("receiving_tds") > 0: L_ += [["REC TD", nice(g("receiving_tds"))]]
    elif grp == "RB":
        L_ += [["CAR", nice(g("carries"))], ["RUSH YDS", nice(g("rushing_yards"))], ["RUSH TD", nice(g("rushing_tds"))]]
        if g("receptions") > 0: L_ += [["REC", nice(g("receptions"))], ["REC YDS", nice(g("receiving_yards"))]] + ([["REC TD", nice(g("receiving_tds"))]] if g("receiving_tds") else [])
    elif grp in ("WR", "TE"):
        L_ += [["REC", nice(g("receptions"))], ["TGT", nice(g("targets"))], ["REC YDS", nice(g("receiving_yards"))], ["REC TD", nice(g("receiving_tds"))]]
        if g("rushing_tds") or g("rushing_yards") >= 30: L_ += [["RUSH YDS", nice(g("rushing_yards"))]] + ([["RUSH TD", nice(g("rushing_tds"))]] if g("rushing_tds") else [])
    else:
        tk = g("def_tackles_solo") + g("def_tackle_assists")
        for lab, v in (("SACKS", g("def_sacks")), ("INT", g("def_interceptions")), ("DEF TD", g("def_tds") + g("fumble_recovery_tds")), ("TKL", tk), ("TFL", g("def_tackles_for_loss")), ("FF", g("def_fumbles_forced")), ("PD", g("def_pass_defended"))):
            if v > 0 and len(L_) < 6: L_.append([lab, nice(v)])
    if g("special_teams_tds") > 0: L_.append(["RETURN TD", nice(g("special_teams_tds"))])
    return L_
rows = {"QB": [], "RB": [], "WR": [], "TE": [], "DEF": []}
best = {}   # idx -> (score, row, grp) for the journeyman clue
for y in YEARS:
    for r in csv.DictReader(open(f"{d}/stats/week_{y}.csv", encoding="utf-8")):
        if r["game_id"] not in sched: continue
        pos = r["position"]; grp = {"QB": "QB", "RB": "RB", "HB": "RB", "FB": "RB", "WR": "WR", "TE": "TE"}.get(pos)
        ppr = fnum(r, "fantasy_points_ppr")
        dscore = fnum(r, "def_sacks") * 2.5 + fnum(r, "def_interceptions") * 4 + (fnum(r, "def_tds") + fnum(r, "fumble_recovery_tds")) * 6 + fnum(r, "def_fumbles_forced") * 1.5
        if grp:
            if ppr >= 30: rows[grp].append((ppr, r))
        elif r["position_group"] in ("DL", "LB", "DB") and (fnum(r, "def_sacks") >= 3.5 or fnum(r, "def_interceptions") >= 3 or fnum(r, "def_tds") + fnum(r, "fumble_recovery_tds") >= 2 or (fnum(r, "def_interceptions") >= 2 and fnum(r, "def_tds") >= 1)):
            rows["DEF"].append((dscore, r))
        # journeyman clue: only for players already in the lineup pool
        pid = gsis2pfr.get(r["player_id"])
        if pid in players and players[pid] in paths:
            i = players[pid]
            ok = (grp and ppr >= 18) or (not grp and (fnum(r, "def_sacks") >= 2 or fnum(r, "def_interceptions") >= 2 or fnum(r, "def_tds") + fnum(r, "fumble_recovery_tds") >= 1))
            sc = ppr if grp else dscore
            if ok and (i not in best or sc > best[i][0]): best[i] = (sc, r, grp or "DEF")
def game_bits(r):
    g = sched[r["game_id"]]; t = fr(r["team"]); home = fr(g["home_team"]) == t
    ts, os_ = (g["home_score"], g["away_score"]) if home else (g["away_score"], g["home_score"])
    return int(r["season"]), int(r["week"]), GT.get(g["game_type"], g["game_type"]), t, fr(r["opponent_team"]), 1 if home else 0, int(float(ts or 0)), int(float(os_ or 0))
boom = []
for grp, cap, per in (("QB", 110, 3), ("RB", 120, 3), ("WR", 120, 3), ("TE", 50, 3), ("DEF", 60, 2)):
    seen_p = collections.Counter(); n = 0
    for sc, r in sorted(rows[grp], key=lambda x: -x[0]):
        if n >= cap: break
        if seen_p[r["player_id"]] >= per: continue
        seen_p[r["player_id"]] += 1; n += 1
        i = stat_idx(r); s_, w_, gt, t, o, home, ts, os_ = game_bits(r)
        j = roster_lookup(jersey, s_, t, gsis2pfr.get(r["player_id"]), P[i][0])
        boom.append([i, s_, w_, gt, t, o, home, ts, os_, grp, round(fnum(r, "fantasy_points_ppr"), 1) if grp != "DEF" else None, int(j) if j not in (None, "") else None, statline(r, grp)])
jmbig = {}
for i, (sc, r, grp) in best.items():
    s_, w_, gt, t, o, home, ts, os_ = game_bits(r)
    jmbig[i] = [s_, w_, gt, t, o, grp, round(fnum(r, "fantasy_points_ppr"), 1) if grp != "DEF" else None, statline(r, grp)]
print("boom games", len(boom), collections.Counter(b[9] for b in boom), "extra players", len(extra), "jm big", len(jmbig), "of", len(paths))
for b in sorted(boom, key=lambda b: -(b[10] or 0))[:6] + [b for b in boom if b[9] == "DEF"][:4] + [b for b in boom if b[0] in extra.values()][:8]:
    print("  ", P[b[0]][0], b[1:12], b[12])

# ---- named games: curated by hand, scores checked against the schedule file where it reaches (1999 on)
spec2 = importlib.util.spec_from_file_location("named", sys.argv[4]); nm2 = importlib.util.module_from_spec(spec2); spec2.loader.exec_module(nm2)
by_date = collections.defaultdict(list)
for g in sched.values(): by_date[g["gameday"]].append(g)
named = []; unchecked = []
for e in nm2.NAMED:
    if e["date"] >= "1999-09-01":
        hit = [g for g in by_date.get(e["date"], []) if {int(float(g["home_score"] or -1)), int(float(g["away_score"] or -1))} == set(e["score"]) and {g["home_team"], g["away_team"]} == set(e["teams"])]
        assert hit, ("NAMED GAME DOES NOT MATCH SCHEDULE", e["name"], [(g["away_team"], g["away_score"], g["home_team"], g["home_score"]) for g in by_date.get(e["date"], [])])
        g = hit[0]; assert g["away_team"] == e["teams"][0] or g["location"] == "Neutral", ("AWAY/HOME ORDER", e["name"], g["away_team"], g["home_team"])
    else: unchecked.append(e["name"])
    named.append([e["name"], e.get("aka", []), e["when"], e["tease"], e["matchup"], e["final"], e["who"]])
print("named games", len(named), "checked against schedule", len(named) - len(unchecked), "older than the file", len(unchecked))

# ---- nicknames: curated by hand, attached by name (and college when two players share a name)
spec = importlib.util.spec_from_file_location("nicknames", sys.argv[3]); nm_mod = importlib.util.module_from_spec(spec); spec.loader.exec_module(nm_mod)
by_norm = collections.defaultdict(list)
for i, x in enumerate(P):
    for n_ in {norm(x[0])} | {norm(a_) for a_ in alias.get(i, [])}: by_norm[n_].append(i)
nick = {}; unmatched = []; ambiguous = []
for key, vals in nm_mod.NICKS.items():
    name, _, college = key.partition("|")
    c = sorted(set(by_norm.get(norm(name), [])))
    if college: c = [i for i in c if P[i][1].lower() == college.lower()]
    else: c = [i for i in c if norm(P[i][0]) == norm(name)] or c
    if not c: unmatched.append(key); continue
    if len(c) > 1: ambiguous.append((key, [(P[i][0], P[i][1], P[i][2]) for i in c])); continue
    out_n = [vals[0]]
    for v in vals:
        for w in (v, v[4:] if v.lower().startswith("the ") else None):
            if w and w not in out_n: out_n.append(w)
    nick[c[0]] = out_n
print("nicknames attached", len(nick), "shown", sum(1 for v in nick.values() if v[0]))
print("NOT IN POOL", unmatched)
print("AMBIGUOUS", ambiguous)
diff = [(names[pid], P[i][0]) for pid, i in players.items() if norm(names[pid]) != norm(P[i][0])]
print("name differs", len(diff), diff[:60])
print("journeymen by starts>=3", sum(1 for i in paths if starts[i] >= 3), ">=4", sum(1 for i in paths if starts[i] >= 4))
slim = {k: [[s[0], s[2], s[3], s[4]] for s in sl] for k, sl in lineups.items()}
for k, sl in lineups.items(): assert [s[1] for s in sl] == ["O"] * 11 + ["D"] * 11 + ["S"] * 2, k
json.dump(dict(players=P, lineups=slim, paths={i: [paths[i], starts[i]] for i in paths}, pos=spos, alias=alias, nick=nick, boom=boom, jmbig=jmbig, named=named), open(out, "w"), separators=(",", ":"), ensure_ascii=False)
print("teams", teams)
print("lineups", len(lineups), "players", len(P), "paths", len(paths), "issues", issues)
print("missing jersey", sum(1 for sl in lineups.values() for s in sl if s[3] is None), "of", sum(len(sl) for sl in lineups.values()))
print("missing college", sum(1 for p in P if not p[1]), "no draft/rookie yr", sum(1 for p in P if not p[2]))
print("labels", collections.Counter(s[2] for sl in lineups.values() for s in sl).most_common())
def show(k):
    print(k, " | ".join(f"{s[2]} #{s[3]} {P[s[0]][0]} {s[4]}%" for s in lineups[k]))
print("aliases", len(alias))
print("KP", [(k, P[s[0]][0], s[2]) for k in ("2020LAC", "2014NE", "2018SEA", "2022BUF") for s in lineups[k][-2:]])
dup = [(k, n) for k, sl in lineups.items() for n, c in collections.Counter(s[0] for s in sl).items() if c > 1]
print("dup players in a lineup", dup)
sizes = collections.Counter(len(sl) for sl in lineups.values()); print("sizes", sizes)
print("draft teams", sorted({x[5] for x in P}))
print("journeymen", len(paths), "starts>=4", sum(1 for i in paths if starts[i] >= 4), "starts>=5", sum(1 for i in paths if starts[i] >= 5))
print("same-name players", [n for n, c in collections.Counter(x[0] for x in P).items() if c > 1])
for nm in ("Ryan Fitzpatrick", "Josh McCown", "Brandin Cooks", "Ndamukong Suh", "DeSean Jackson"):
    i = [j for j, x in enumerate(P) if x[0] == nm]
    print(nm, P[i[0]], paths.get(i[0]), alias.get(i[0]))
