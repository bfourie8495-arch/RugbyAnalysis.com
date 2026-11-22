"""Trends from the play-by-play (espn_events.json, written by update.py): when each team scores and concedes,
how games turn, who scores the tries, what the bench adds and what a yellow card costs. Used by
build_tournaments.py for each tournament edition whose games have play-by-play (the Nations Championship first),
and shown in the app's tournament screen and on the website's Nations Championship trends page.

Everything is counted from events, so one game with a missing feed only drops out of these numbers; the
tables and results still come from the results file."""
import collections, datetime, json, re

PTS = {'T': 5, 'PT': 7, 'C': 2, 'P': 3, 'D': 3}
WINDOWS = [(1, 20), (21, 40), (41, 60), (61, 80)]  # quarters of the game, by minute
FORWARD_WORDS = ('prop', 'hooker', 'lock', 'flanker', 'number 8', 'number eight', 'no. 8', 'back row', 'forward', 'loose')
BIN = 10  # minutes a yellow card lasts


def load(f, default):
    try:
        return json.load(open(f, encoding='utf-8'))
    except (FileNotFoundError, ValueError):
        return default


def surname(name):
    parts = (name or '').split()
    return ' '.join(parts[1:]) if len(parts) > 1 else name or ''


def window(m):
    for i, (a, b) in enumerate(WINDOWS):
        if a <= m <= b:
            return i
    return None


def match_games(rows, events):
    """Pair each result (a row of the results file) with its play-by-play: same teams, date within a day,
    and the events must add up to the score. Returns [(result row, home, away, events as the result names the sides)]."""
    idx = collections.defaultdict(list)
    for eid, (lg, d, h, a, hs, as_, ev) in events.items():
        idx[frozenset((h, a))].append((d, eid, h, a, hs, as_, ev))
    out = []
    for r in rows:
        d0 = datetime.date.fromisoformat(r.date)
        for d, eid, h, a, hs, as_, ev in idx.get(frozenset((r.home_team, r.away_team)), []):
            if abs((datetime.date.fromisoformat(d) - d0).days) > 1:
                continue
            flip = h != r.home_team
            if flip:
                ev = [[m, half, c, {'h': 'a', 'a': 'h'}.get(s, s), aid] for m, half, c, s, aid in ev]
                hs, as_ = as_, hs
            if (hs, as_) != (int(r.home_score), int(r.away_score)):
                continue
            out.append((r, eid, ev))
            break
    return out


def build(rows, fixtures=()):
    """Trends for one tournament edition. rows: its results (itertuples of the results file, dates as YYYY-MM-DD).
    fixtures: its remaining fixtures ({'h','a',...}), for the side-by-side match-ups. None if no game has play-by-play."""
    events = load('espn_events.json', {})
    rost = load('espn_rosters.json', {})
    ath = load('espn_athletes.json', {})
    games = match_games(rows, events)
    if not games:
        return None
    T = collections.defaultdict(lambda: collections.defaultdict(int))
    W = {'tries': [0] * len(WINDOWS), 'pts': [0] * len(WINDOWS)}
    scorers, kickers = collections.Counter(), collections.Counter()
    comp = collections.Counter()
    comebacks = []

    def is_forward(aid, jersey, pos):
        if 1 <= jersey <= 8:
            return True
        if 9 <= jersey <= 15:
            return False
        p = ((ath.get(aid) or {}).get('pos') or '').lower()
        return any(w in p for w in FORWARD_WORDS)

    for r, eid, ev in games:
        h, a = r.home_team, r.away_team
        team = {'h': h, 'a': a}
        opp = {'h': a, 'a': h}
        # who wore which shirt (jersey >= 16 = replacement)
        shirt = {}
        for sd in (rost.get(eid) or [0, 0, []])[2]:
            for p in sd[2]:
                shirt[p[0]] = (p[1], p[4])
        hs, as_ = int(r.home_score), int(r.away_score)
        res = {'h': (hs > as_) - (hs < as_), 'a': (as_ > hs) - (as_ < hs)}
        for s in 'ha':
            x = T[team[s]]
            x['g'] += 1
            x['w'] += res[s] == 1
            x['pf'] += hs if s == 'h' else as_
            x['pa'] += as_ if s == 'h' else hs
        score = {'h': 0, 'a': 0}
        first_try = None
        worst = {'h': 0, 'a': 0}  # each side's biggest deficit during the game
        lead_changes, leader = 0, 0
        cards = []  # (minute, side) of yellow cards, for the sin-bin count
        ht = None
        for m, half, c, s, aid in ev:
            if s not in 'ha':
                continue
            if half == 2 and ht is None:
                ht = dict(score)
            if c in PTS:
                pts = PTS[c]
                score[s] += pts
                x, y = T[team[s]], T[opp[s]]
                wi = window(m) if half else None
                if wi is not None:
                    x[f'pf{wi}'] += pts
                    y[f'pa{wi}'] += pts
                    W['pts'][wi] += pts
                if c in ('T', 'PT'):
                    x['tf'] += 1
                    y['ta'] += 1
                    comp['tries'] += 1
                    if wi is not None:
                        x[f'tf{wi}'] += 1
                        y[f'ta{wi}'] += 1
                        W['tries'][wi] += 1
                    if first_try is None and half:
                        first_try = s
                    if c == 'T' and aid:
                        jersey, pos = shirt.get(aid, (0, ''))
                        name = (ath.get(aid) or {}).get('n') or ''
                        scorers[(aid, team[s])] += 1
                        x['tFwd' if is_forward(aid, jersey, pos) else 'tBack'] += 1
                        if jersey >= 16:
                            x['tBench'] += 1
                    elif c == 'PT':
                        x['tPen'] += 1
                if aid and c != 'PT':
                    kickers[(aid, team[s])] += pts
                    if shirt.get(aid, (0,))[0] >= 16:
                        x['ptsBench'] += pts
                if c == 'C':
                    x['conMade'] += 1
                if c == 'P':
                    x['pens'] += 1
                if c == 'D':
                    x['drops'] += 1
                # sin-bin: points either way while a yellow card is running
                for cm, cs in cards:
                    if half and cm <= m < cm + BIN:
                        if cs == s:
                            T[team[s]]['binFor'] += pts
                        else:
                            T[team[cs]]['binAgainst'] += pts
                diff = score['h'] - score['a']
                now = (diff > 0) - (diff < 0)
                if now and leader and now != leader:
                    lead_changes += 1
                if now:
                    leader = now
                worst['h'] = min(worst['h'], diff)
                worst['a'] = min(worst['a'], -diff)
            elif c == 'Y':
                T[team[s]]['yc'] += 1
                if half:
                    cards.append((m, s))
            elif c == 'R':
                T[team[s]]['rc'] += 1
        if ht is None:
            ht = dict(score)
        comp['games'] += 1
        comp['leadChanges'] += lead_changes
        for s in 'ha':
            x = T[team[s]]
            x['conAtt'] += sum(1 for e in ev if e[3] == s and e[2] == 'T')
            mine, theirs = ht[s], ht['a' if s == 'h' else 'h']
            if mine > theirs:
                x['htLead'] += 1
                x['htLeadWon'] += res[s] == 1
            elif mine < theirs:
                x['htBehind'] += 1
                x['htBehindWon'] += res[s] == 1
            if first_try == s:
                x['firstTry'] += 1
                x['firstTryWon'] += res[s] == 1
            if res[s] == 1 and worst[s] <= -7:
                comebacks.append([-worst[s], r.date, team[s], opp[s], hs if s == 'h' else as_, as_ if s == 'h' else hs])
        # competition-wide: half-time leaders, first try
        if ht['h'] != ht['a']:
            lead = 'h' if ht['h'] > ht['a'] else 'a'
            comp['htDecided'] += 1
            comp['htLeaderWon'] += res[lead] == 1
        if first_try:
            comp['firstTryGames'] += 1
            comp['firstTryWon'] += res[first_try] == 1
        comp['secondHalfPts'] += sum(PTS.get(e[2], 0) for e in ev if e[1] == 2)
        comp['pts'] += hs + as_

    def name_of(aid):
        n = (ath.get(aid) or {}).get('n') or ''
        return n or aid

    teams = {}
    for t, x in T.items():
        g = x['g']
        teams[t] = {
            'g': g, 'w': x['w'], 'pf': x['pf'], 'pa': x['pa'], 'tf': x['tf'], 'ta': x['ta'],
            # points scored and conceded in each quarter (1-20, 21-40, 41-60, 61-80), totals over the games
            'pfQ': [x[f'pf{i}'] for i in range(len(WINDOWS))], 'paQ': [x[f'pa{i}'] for i in range(len(WINDOWS))],
            'tfQ': [x[f'tf{i}'] for i in range(len(WINDOWS))], 'taQ': [x[f'ta{i}'] for i in range(len(WINDOWS))],
            'tFwd': x['tFwd'], 'tBack': x['tBack'], 'tPen': x['tPen'], 'tBench': x['tBench'], 'ptsBench': x['ptsBench'],
            'con': [x['conMade'], x['conAtt']], 'pens': x['pens'], 'drops': x['drops'],
            'yc': x['yc'], 'rc': x['rc'], 'bin': [x['binFor'], x['binAgainst']],
            'ht': [x['htLead'], x['htLeadWon'], x['htBehind'], x['htBehindWon']],
            'first': [x['firstTry'], x['firstTryWon']],
        }
        mine = [(name_of(aid), n) for (aid, tm), n in scorers.items() if tm == t]
        if mine:
            teams[t]['scorers'] = [[surname(n), k] for n, k in sorted(mine, key=lambda z: (-z[1], z[0]))[:3]]
    top_t = sorted(((name_of(aid), tm, n) for (aid, tm), n in scorers.items()), key=lambda z: (-z[2], z[0]))[:10]
    top_p = sorted(((name_of(aid), tm, n) for (aid, tm), n in kickers.items()), key=lambda z: (-z[2], z[0]))[:10]
    out = {'games': comp['games'], 'of': len(rows), 'windows': ['1–20', '21–40', '41–60', '61–80'],
           'triesQ': W['tries'], 'ptsQ': W['pts'], 'tries': comp['tries'],
           'htLeader': [comp['htLeaderWon'], comp['htDecided']], 'firstTry': [comp['firstTryWon'], comp['firstTryGames']],
           'leadChanges': round(comp['leadChanges'] / max(1, comp['games']), 1),
           'secondHalf': round(100 * comp['secondHalfPts'] / max(1, comp['pts'])),
           'comebacks': sorted(comebacks, key=lambda z: (-z[0], z[1]))[:5],
           'tryScorers': [list(z) for z in top_t], 'pointsScorers': [list(z) for z in top_p], 'teams': teams}
    out['insights'] = insights(out)
    out['matchups'] = [m for f in fixtures if (m := matchup(out, f['h'], f['a']))]
    return out


def pct(a, b):
    return round(100 * a / b) if b else 0


def per(x, g):
    return round(x / g, 1) if g else 0


def insights(t):
    """Plain-English headlines for the whole tournament, most striking first."""
    lines = []
    tq, games = t['triesQ'], t['games']
    if t['tries']:
        busiest = max(range(len(tq)), key=lambda i: tq[i])
        if max(tq) - min(tq) <= 0.15 * max(tq):
            lines.append(f"Tries have come evenly across the 80 minutes: {', '.join(map(str, tq))} in each quarter, a little fewer late on." if tq[-1] == min(tq)
                         else f"Tries have come evenly across the 80 minutes: {', '.join(map(str, tq))} in each quarter.")
        else:
            lines.append(f"Minutes {t['windows'][busiest]} have produced the most tries: {tq[busiest]} of {t['tries']} ({pct(tq[busiest], t['tries'])}%).")
    won, of = t['firstTry']
    if of:
        lines.append(f"The team that scored the first try won {won} of {of} games ({pct(won, of)}%).")
    won, of = t['htLeader']
    if of:
        lines.append(f"Half-time leaders went on to win {won} of {of} ({pct(won, of)}%), so {of - won} games turned round after the break.")
    lines.append(f"{t['secondHalf']}% of all points came in the second half.")
    T = t['teams']
    full = {k: v for k, v in T.items() if v['g'] >= max(2, games // len(T))}
    if full:
        fin = max(full, key=lambda k: (full[k]['pfQ'][3] - full[k]['paQ'][3]) / full[k]['g'])
        v = full[fin]
        lines.append(f"Best finishers: {fin} have outscored opponents {v['pfQ'][3]}–{v['paQ'][3]} in the last 20 minutes.")
        fast = max(full, key=lambda k: (full[k]['pfQ'][0] - full[k]['paQ'][0]) / full[k]['g'])
        v = full[fast]
        lines.append(f"Fastest starters: {fast} lead the first-20-minute scoring at {v['pfQ'][0]}–{v['paQ'][0]}.")
        bench = max(full, key=lambda k: full[k]['ptsBench'] / full[k]['g'])
        if full[bench]['ptsBench']:
            n = full[bench]['tBench']
            lines.append(f"{bench}’s bench has scored the most: {full[bench]['ptsBench']} points, with {n} {'try' if n == 1 else 'tries'}.")
        fwd = max(full, key=lambda k: pct(full[k]['tFwd'], full[k]['tFwd'] + full[k]['tBack']))
        v = full[fwd]
        lines.append(f"{fwd} lean most on their forwards: {v['tFwd']} of their {v['tFwd'] + v['tBack']} named try scorers were forwards.")
        binned = max(full, key=lambda k: full[k]['bin'][1] - full[k]['bin'][0])
        v = full[binned]
        if v['yc'] and v['bin'][1] > v['bin'][0]:
            lines.append(f"Yellow cards have cost {binned} most: {v['yc']} cards, and they were outscored {v['bin'][1]}–{v['bin'][0]} while a player was in the bin.")
    if t['comebacks']:
        d, date, w, l, ws, ls = t['comebacks'][0]
        lines.append(f"Biggest comeback: {w} came from {d} points down to beat {l} {ws}–{ls}.")
    return lines


def matchup(t, h, a):
    """Side by side numbers and talking points for one fixture, when both teams have play-by-play."""
    T = t['teams']
    if h not in T or a not in T:
        return None
    x, y = T[h], T[a]
    rows = [
        ['Points a game', per(x['pf'], x['g']), per(y['pf'], y['g'])],
        ['Conceded a game', per(x['pa'], x['g']), per(y['pa'], y['g'])],
        ['Tries a game', per(x['tf'], x['g']), per(y['tf'], y['g'])],
        ['First 20 min (for–against)', f"{x['pfQ'][0]}–{x['paQ'][0]}", f"{y['pfQ'][0]}–{y['paQ'][0]}"],
        ['Last 20 min (for–against)', f"{x['pfQ'][3]}–{x['paQ'][3]}", f"{y['pfQ'][3]}–{y['paQ'][3]}"],
        ['Second-half points', f"{pct(x['pfQ'][2] + x['pfQ'][3], x['pf'])}%", f"{pct(y['pfQ'][2] + y['pfQ'][3], y['pf'])}%"],
        ['Tries by forwards', f"{x['tFwd']} of {x['tFwd'] + x['tBack']}", f"{y['tFwd']} of {y['tFwd'] + y['tBack']}"],
        ['Bench points', x['ptsBench'], y['ptsBench']],
        ['Conversions', f"{x['con'][0]}/{x['con'][1]}", f"{y['con'][0]}/{y['con'][1]}"],
        ['Cards (yellow, red)', f"{x['yc']}, {x['rc']}", f"{y['yc']}, {y['rc']}"],
        ['Scored first try, won', f"{x['first'][1]} of {x['first'][0]}", f"{y['first'][1]} of {y['first'][0]}"],
    ]
    talk = []
    # the strongest contrast in when they score
    for i, label in ((3, 'last 20 minutes'), (0, 'first 20 minutes')):
        dx = (x['pfQ'][i] - x['paQ'][i]) / x['g']
        dy = (y['pfQ'][i] - y['paQ'][i]) / y['g']
        if abs(dx - dy) >= 4:
            def say(t_, d):
                d = round(d, 1)
                return f"{t_} {'win' if d > 0 else 'lose'} the {label} by {abs(d)} points a game on average" if d else f"{t_} break even in the {label}"
            first, second = ((h, dx), (a, dy)) if dx > dy else ((a, dy), (h, dx))
            talk.append(f"{say(*first)}; {say(*second).replace(' the ' + label, ' them', 1).replace(' points a game on average', '')}.")
    if x['ht'][2] + y['ht'][2]:
        for t_, v in ((h, x), (a, y)):
            if v['ht'][3]:
                talk.append(f"{t_} have come from behind at half-time to win {v['ht'][3]} of {v['ht'][2]}.")
    for t_, v in ((h, x), (a, y)):
        if v['yc'] + v['rc'] >= 4:
            talk.append(f"Discipline: {t_} have had {v['yc']} yellow {'card' if v['yc'] == 1 else 'cards'}" + (f" and {v['rc']} red" if v['rc'] else '') + f" in {v['g']} games.")
    for t_, v in ((h, x), (a, y)):
        if v.get('scorers'):
            n, k = v['scorers'][0]
            talk.append(f"{t_}’s top try scorer is {n} with {k}.")
    return {'h': h, 'a': a, 'rows': rows, 'talk': talk}
