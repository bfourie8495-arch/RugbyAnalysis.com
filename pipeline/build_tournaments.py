"""Build the app's tournaments feed: the latest edition of each major international tournament (tables with
bonus points, or a series record where there is no table), which of them each nation is in and where it sits,
and the next Rugby World Cup (pools, every match with its kick-off in UTC, the knockout path, and live pool
tables once it starts). Writes ../site/app/tournaments.json, served at
https://rugbyanalysis.com/app/tournaments.json for the RugbyAnalysis app.

Runs from build_all.py after update.py. Each tournament picks its latest edition from the results by itself;
the World Cup draw and schedule below are typed in from World Rugby's published schedule (kick-offs are local
to each venue and converted here). If anything goes wrong, the previous file is kept and the run shows a
yellow warning instead of stopping the rest of the site build."""
import json, os, re, datetime, collections, random, statistics
from zoneinfo import ZoneInfo
import pandas as pd

OUT = os.path.join('..', 'site', 'app', 'tournaments.json')
TODAY = datetime.date.today().isoformat()
ALIAS = {'United States of America': 'United States', 'USA': 'United States', 'Hong Kong China': 'Hong Kong',
         'Czechia': 'Czech Republic'}

# ---------------------------------------------------------------- tournaments
# pat: regex on the results' competition name, group 1 = the edition's year.
# fx: the name the fixtures feed uses (before " · Round n").  pts: 'bp' = 4 win, 2 draw, +1 for 4+ tries,
# +1 for losing by 7 or fewer; 'bp_gs' adds 3 for a Grand Slam.  fmt 'series' = no table, just each team's record.
TOURNAMENTS = [
    {'id': 'nc', 'g': 'm', 'name': 'Nations Championship', 'pat': r'^(\d{4}) Nations Championship( Southern Hemisphere Series)?$',
     'fx': 'Nations Championship', 'pts': 'bp',
     'groups': [['Northern group', ['England', 'France', 'Ireland', 'Italy', 'Scotland', 'Wales']],
                ['Southern group', ['New Zealand', 'South Africa', 'Australia', 'Argentina', 'Fiji', 'Japan']]],
     'liveUntil': {2026: '2026-11-29'},
     'about': 'Each team plays all six teams in the other group: three Tests in July, three in November.',
     'finals': 'Finals weekend at Twickenham, 27 to 29 November 2026: each place in the Northern group plays the same place in the Southern group, so 1st v 1st decides the title.'},
    {'id': '6n', 'g': 'm', 'name': 'Six Nations', 'pat': r'^(\d{4}) Six Nations Championship$', 'fx': 'Six Nations Championship',
     'pts': 'bp_gs', 'about': 'Five rounds every February and March. A Grand Slam (winning all five) earns 3 bonus points.'},
    {'id': 'rc', 'g': 'm', 'name': 'Rugby Championship', 'pat': r'^(\d{4}) Rugby Championship$', 'fx': 'Rugby Championship',
     'pts': 'bp', 'about': 'South Africa, New Zealand, Australia and Argentina, home and away.'},
    {'id': 'wnc', 'g': 'm', 'name': 'World Rugby Nations Cup', 'pat': r'^(\d{4}) World Rugby Nations Cup', 'fx': 'World Rugby Nations Cup',
     'pts': 'bp', 'checked': False,
     'groups': [['Americas and Pacific pool', ['Canada', 'Chile', 'Samoa', 'Tonga', 'United States', 'Uruguay']],
                ['Europe, Africa and Asia pool', ['Georgia', 'Hong Kong', 'Portugal', 'Romania', 'Spain', 'Zimbabwe']]],
     'liveUntil': {2026: '2026-11-21'},
     'about': 'Twelve World Cup qualifiers. Each plays the six teams in the other pool across July and November, and each pool crowns a champion.'},
    {'id': 'w6n', 'g': 'w', 'name': "Women's Six Nations", 'pat': r"^(\d{4}) Women's Six Nations Championship$",
     'fx': "Women's Six Nations Championship", 'pts': 'bp_gs', 'about': 'Five rounds every spring. A Grand Slam earns 3 bonus points.'},
    {'id': 'p4', 'g': 'w', 'name': 'Pacific Four Series', 'pat': r'^(\d{4}) Pacific Four Series$', 'fx': 'Pacific Four Series',
     'pts': 'bp', 'loc': True, 'about': 'Canada, New Zealand, Australia and the United States play each other once.'},
    {'id': 'wxv', 'g': 'w', 'name': 'WXV Global Series', 'pat': r'^(\d{4}) WXV Global Series$', 'fx': 'WXV Global Series',
     'fmt': 'series', 'about': 'Touring Tests between the top women’s teams from September to October, with no league table.'},
    {'id': 'wxvc', 'g': 'w', 'name': 'WXV Global Series Challenger', 'pat': r'^(\d{4}) WXV Global Series Challenger$',
     'fx': 'WXV Global Series Challenger', 'fmt': 'series', 'about': 'The second tier: two pools of three in Hong Kong, each team playing the other pool.'},
]

# ---------------------------------------------------------------- Rugby World Cup 2027 (World Rugby schedule, Feb 2026)
TZ = {'Perth Stadium': 'Australia/Perth', 'Stadium Australia': 'Australia/Sydney', 'Sydney Football Stadium': 'Australia/Sydney',
      'Newcastle Stadium': 'Australia/Sydney', 'Docklands Stadium': 'Australia/Melbourne', 'Adelaide Oval': 'Australia/Adelaide',
      'Brisbane Stadium': 'Australia/Brisbane', 'North Queensland Stadium': 'Australia/Brisbane'}
CITY = {'Perth Stadium': 'Perth', 'Stadium Australia': 'Sydney', 'Sydney Football Stadium': 'Sydney', 'Newcastle Stadium': 'Newcastle',
        'Docklands Stadium': 'Melbourne', 'Adelaide Oval': 'Adelaide', 'Brisbane Stadium': 'Brisbane', 'North Queensland Stadium': 'Townsville'}
RWC = {
    'g': 'm', 'name': 'Rugby World Cup 2027', 'host': 'Australia', 'start': '2027-10-01', 'end': '2027-11-13',
    'pat': r"^2027 (Men's )?Rugby World Cup$",
    'format': '24 teams in six pools of four. The top two in each pool and the four best third-placed teams reach a new round of 16, then quarter-finals, semi-finals and the final.',
    'pools': {'A': ['New Zealand', 'Australia', 'Chile', 'Hong Kong'], 'B': ['South Africa', 'Italy', 'Georgia', 'Romania'],
              'C': ['Argentina', 'Fiji', 'Spain', 'Canada'], 'D': ['Ireland', 'Scotland', 'Uruguay', 'Portugal'],
              'E': ['France', 'Japan', 'United States', 'Samoa'], 'F': ['England', 'Wales', 'Tonga', 'Zimbabwe']},
    # date, local kick-off, home, away, venue
    'pool_matches': [
        ('2027-10-01', '18:45', 'Australia', 'Hong Kong', 'Perth Stadium'), ('2027-10-02', '13:15', 'New Zealand', 'Chile', 'Perth Stadium'),
        ('2027-10-09', '17:10', 'New Zealand', 'Australia', 'Stadium Australia'), ('2027-10-09', '20:15', 'Chile', 'Hong Kong', 'North Queensland Stadium'),
        ('2027-10-15', '17:15', 'New Zealand', 'Hong Kong', 'Docklands Stadium'), ('2027-10-16', '15:10', 'Australia', 'Chile', 'Brisbane Stadium'),
        ('2027-10-03', '14:15', 'South Africa', 'Italy', 'Adelaide Oval'), ('2027-10-03', '20:15', 'Georgia', 'Romania', 'North Queensland Stadium'),
        ('2027-10-10', '16:45', 'South Africa', 'Georgia', 'Brisbane Stadium'), ('2027-10-11', '19:45', 'Italy', 'Romania', 'Sydney Football Stadium'),
        ('2027-10-17', '12:15', 'Italy', 'Georgia', 'Newcastle Stadium'), ('2027-10-17', '19:15', 'South Africa', 'Romania', 'Perth Stadium'),
        ('2027-10-04', '14:15', 'Fiji', 'Spain', 'Newcastle Stadium'), ('2027-10-04', '18:45', 'Argentina', 'Canada', 'Brisbane Stadium'),
        ('2027-10-10', '12:15', 'Fiji', 'Canada', 'Adelaide Oval'), ('2027-10-10', '15:15', 'Argentina', 'Spain', 'Docklands Stadium'),
        ('2027-10-16', '13:15', 'Argentina', 'Fiji', 'Adelaide Oval'), ('2027-10-16', '20:15', 'Spain', 'Canada', 'North Queensland Stadium'),
        ('2027-10-03', '17:15', 'Scotland', 'Uruguay', 'Docklands Stadium'), ('2027-10-04', '17:15', 'Ireland', 'Portugal', 'Sydney Football Stadium'),
        ('2027-10-10', '17:45', 'Ireland', 'Scotland', 'Perth Stadium'), ('2027-10-11', '17:15', 'Uruguay', 'Portugal', 'Newcastle Stadium'),
        ('2027-10-17', '14:45', 'Ireland', 'Uruguay', 'Docklands Stadium'), ('2027-10-17', '16:15', 'Scotland', 'Portugal', 'Brisbane Stadium'),
        ('2027-10-02', '17:45', 'France', 'United States', 'Docklands Stadium'), ('2027-10-03', '12:15', 'Japan', 'Samoa', 'Newcastle Stadium'),
        ('2027-10-09', '12:15', 'United States', 'Samoa', 'Perth Stadium'), ('2027-10-09', '18:45', 'France', 'Japan', 'Brisbane Stadium'),
        ('2027-10-15', '20:00', 'Japan', 'United States', 'Adelaide Oval'), ('2027-10-17', '19:45', 'France', 'Samoa', 'Sydney Football Stadium'),
        ('2027-10-02', '12:15', 'Wales', 'Zimbabwe', 'Adelaide Oval'), ('2027-10-02', '20:15', 'England', 'Tonga', 'Brisbane Stadium'),
        ('2027-10-08', '18:15', 'Wales', 'Tonga', 'Docklands Stadium'), ('2027-10-08', '20:15', 'England', 'Zimbabwe', 'Adelaide Oval'),
        ('2027-10-15', '20:15', 'Tonga', 'Zimbabwe', 'North Queensland Stadium'), ('2027-10-16', '19:45', 'England', 'Wales', 'Stadium Australia'),
    ],
    'knockouts': [
        ('R16 1', 'Round of 16', '2027-10-23', '14:15', '2nd Pool C', '2nd Pool F', 'Sydney Football Stadium'),
        ('R16 2', 'Round of 16', '2027-10-23', '15:45', 'Winner Pool A', '3rd Pool C, E or F', 'Brisbane Stadium'),
        ('R16 3', 'Round of 16', '2027-10-23', '19:15', 'Winner Pool E', '2nd Pool D', 'Docklands Stadium'),
        ('R16 4', 'Round of 16', '2027-10-23', '18:45', 'Winner Pool B', '3rd Pool D, E or F', 'Perth Stadium'),
        ('R16 5', 'Round of 16', '2027-10-24', '14:15', 'Winner Pool C', '3rd Pool A, E or F', 'Sydney Football Stadium'),
        ('R16 6', 'Round of 16', '2027-10-24', '16:45', 'Winner Pool D', '3rd Pool B, E or F', 'Docklands Stadium'),
        ('R16 7', 'Round of 16', '2027-10-24', '18:15', '2nd Pool A', '2nd Pool E', 'Brisbane Stadium'),
        ('R16 8', 'Round of 16', '2027-10-24', '18:45', 'Winner Pool F', '2nd Pool B', 'Perth Stadium'),
        ('QF 1', 'Quarter-final', '2027-10-30', '16:45', 'Winner R16 2', 'Winner R16 4', 'Stadium Australia'),
        ('QF 2', 'Quarter-final', '2027-10-30', '18:45', 'Winner R16 1', 'Winner R16 3', 'Brisbane Stadium'),
        ('QF 3', 'Quarter-final', '2027-10-31', '16:00', 'Winner R16 5', 'Winner R16 6', 'Brisbane Stadium'),
        ('QF 4', 'Quarter-final', '2027-10-31', '20:00', 'Winner R16 7', 'Winner R16 8', 'Stadium Australia'),
        ('SF 1', 'Semi-final', '2027-11-05', '20:00', 'Winner QF 1', 'Winner QF 2', 'Stadium Australia'),
        ('SF 2', 'Semi-final', '2027-11-06', '20:00', 'Winner QF 3', 'Winner QF 4', 'Stadium Australia'),
        ('Bronze', 'Bronze final', '2027-11-12', '19:45', 'Loser SF 1', 'Loser SF 2', 'Stadium Australia'),
        ('Final', 'Final', '2027-11-13', '20:00', 'Winner SF 1', 'Winner SF 2', 'Stadium Australia'),
    ],
}
# the women's next World Cup: host and size confirmed, dates and draw not yet
RWC_W = {'g': 'w', 'name': "Women's Rugby World Cup 2029", 'host': 'Australia', 'teams': 16, 'start': None,
         'qualified': [['Australia', 'Hosts'], ['England', '2025 champions'], ['Canada', '2025 runners-up'],
                       ['New Zealand', '2025 third place'], ['France', '2025 semi-finalists']],
         'note': 'Dates, venues and the draw are still to be announced. The 2025 semi-finalists and the hosts are already in.'}


def utc(date, hm, venue):
    local = datetime.datetime.fromisoformat(date + 'T' + hm).replace(tzinfo=ZoneInfo(TZ[venue]))
    return local.astimezone(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%MZ')


def load(f, g):
    d = pd.read_csv(f, sep=';', low_memory=False)
    d['date'] = d.date.astype(str).str.replace('/', '-')
    d['g'] = g
    for c in ('home_team', 'away_team'):
        d[c] = d[c].map(lambda x: ALIAS.get(x, x))
    return d


def table(rows_df, teams, pts):
    """League table from a set of results. Tries feed the try bonus only where they're recorded."""
    T = {t: dict(t=t, p=0, w=0, d=0, l=0, pf=0, pa=0, tf=0, tb=0, lb=0, gs=0, pts=0, tk=True) for t in teams}
    for r in rows_df.itertuples():
        for me, op, ms, os_, mt in ((r.home_team, r.away_team, r.home_score, r.away_score, r.home_tries),
                                     (r.away_team, r.home_team, r.away_score, r.home_score, r.away_tries)):
            if me not in T: continue
            x = T[me]; ms, os_ = int(ms), int(os_)
            x['p'] += 1; x['pf'] += ms; x['pa'] += os_
            if pd.isna(mt): x['tk'] = False
            else: x['tf'] += int(mt)
            if ms > os_: x['w'] += 1; x['pts'] += 4
            elif ms == os_: x['d'] += 1; x['pts'] += 2
            else:
                x['l'] += 1
                if os_ - ms <= 7: x['lb'] += 1; x['pts'] += 1
            if not pd.isna(mt) and int(mt) >= 4: x['tb'] += 1; x['pts'] += 1
    games = max([x['p'] for x in T.values()] + [0])
    for x in T.values():
        x['pd'] = x['pf'] - x['pa']
        if pts == 'bp_gs' and games >= 5 and x['p'] == 5 and x['w'] == 5: x['gs'] = 3; x['pts'] += 3
    rows = sorted(T.values(), key=lambda x: (-x['pts'], -x['pd'], -x['tf'], -x['pf'], x['t']))
    for i, x in enumerate(rows): x['pos'] = i + 1
    return rows, all(x['tk'] for x in rows if x['p'])


def series(rows_df):
    R = collections.defaultdict(lambda: dict(p=0, w=0, d=0, l=0, pf=0, pa=0))
    for r in rows_df.itertuples():
        for me, ms, os_ in ((r.home_team, r.home_score, r.away_score), (r.away_team, r.away_score, r.home_score)):
            x = R[me]; ms, os_ = int(ms), int(os_)
            x['p'] += 1; x['pf'] += ms; x['pa'] += os_
            x['w' if ms > os_ else 'd' if ms == os_ else 'l'] += 1
    return R


def fixture_list(FX, g, name, since):
    out = []
    for f in FX:
        if f.get('g', 'm') != g or f['c'].split(' · ')[0] != name or f['d'] < since: continue
        out.append({'d': f['d'], 'ko': f.get('ko'), 'h': ALIAS.get(f['h'], f['h']), 'a': ALIAS.get(f['a'], f['a']),
                    'v': f.get('v', ''), 'r': f['c'].split(' · ')[1] if ' · ' in f['c'] else ''})
    return sorted(out, key=lambda x: (x['d'], x['ko'] or ''))


def res_list(df):
    return [{'d': r.date, 'h': r.home_team, 'a': r.away_team, 'hs': int(r.home_score), 'as': int(r.away_score)}
            for r in df.sort_values('date').itertuples()]


def build_tournament(cfg, RES, FX):
    df = RES[RES.g == cfg['g']]
    hit = df[df.competition.str.match(cfg['pat'], na=False)]
    if hit.empty: return None
    year = hit.competition.str.extract(cfg['pat'])[0].astype(int).max()
    ed = hit[hit.competition.str.startswith(str(year))].copy()
    if cfg.get('loc'):  # Pacific Four: Australia v New Zealand doubles as the O'Reilly Cup and can be filed under that name
        loc = df[(df.competition == "%d Laurie O'Reilly Cup" % year)]
        if len(ed) < 6 and not loc.empty:
            lo, hi = ed.date.min(), (pd.Timestamp(ed.date.max()) + pd.Timedelta(days=10)).strftime('%Y-%m-%d')
            ed = pd.concat([ed, loc[(loc.date >= lo) & (loc.date <= hi)]])
    ed = ed.drop_duplicates(['date', 'home_team', 'away_team'])
    fx = fixture_list(FX, cfg['g'], cfg['fx'], max(TODAY, ed.date.max()))
    teams = sorted(set(ed.home_team) | set(ed.away_team) | {t for f in fx for t in (f['h'], f['a'])})
    later = [f for f in fx if int(f['d'][:4]) > year]
    running = [f for f in fx if int(f['d'][:4]) <= year] or TODAY <= cfg.get('liveUntil', {}).get(year, '')
    status = 'live' if running else 'next' if later else 'done'
    out = {'id': cfg['id'], 'g': cfg['g'], 'name': cfg['name'], 'season': str(year), 'status': status,
           'about': cfg.get('about', ''), 'finals': cfg.get('finals', ''), 'fmt': cfg.get('fmt', 'table'),
           'checked': cfg.get('checked', True), 'played': len(ed), 'last': ed.date.max(),
           'results': res_list(ed)[-12:], 'fixtures': fx[:18]}
    if out['fmt'] == 'series':
        S = series(ed)
        out['teams'] = {t: S[t] for t in sorted(S, key=lambda t: (-S[t]['w'], -(S[t]['pf'] - S[t]['pa'])))}
        return out
    groups = cfg.get('groups') or [['', teams]]
    out['groups'] = []
    allknown = True
    for gname, gteams in groups:
        rows, known = table(ed, gteams, cfg['pts'])
        allknown = allknown and known
        out['groups'].append({'name': gname, 'rows': [{k: x[k] for k in ('pos', 't', 'p', 'w', 'd', 'l', 'pf', 'pa', 'pd', 'tb', 'lb', 'gs', 'pts')} for x in rows]})
    out['triesKnown'] = allknown
    return out


def build_rwc(RES, ranks):
    pools, team_pool = RWC['pools'], {t: p for p, ts in RWC['pools'].items() for t in ts}
    matches = []
    for d, hm, h, a, v in RWC['pool_matches']:
        matches.append({'d': d, 'ko': utc(d, hm, v), 'local': hm, 'h': h, 'a': a, 'v': v, 'city': CITY[v], 'pool': team_pool[h]})
    matches.sort(key=lambda m: m['ko'])
    res = RES[(RES.g == 'm') & RES.competition.str.match(RWC['pat'], na=False)]
    by = {(r.home_team, r.away_team): r for r in res.itertuples()}
    for m in matches:
        r = by.get((m['h'], m['a'])) or by.get((m['a'], m['h']))
        if r is not None:
            m['hs'], m['as'] = (int(r.home_score), int(r.away_score)) if r.home_team == m['h'] else (int(r.away_score), int(r.home_score))
    out_pools = []
    for p, ts in pools.items():
        rows, _ = table(res[res.home_team.isin(ts) & res.away_team.isin(ts)], ts, 'bp')
        if not any(x['p'] for x in rows):  # before kick-off: order by world ranking
            rows.sort(key=lambda x: ranks.get(x['t'], 999))
            for i, x in enumerate(rows): x['pos'] = i + 1
        out_pools.append({'p': p, 'rows': [{k: x[k] for k in ('pos', 't', 'p', 'w', 'd', 'l', 'pd', 'tb', 'lb', 'pts')} for x in rows]})
    ko = [{'id': i, 'round': rnd, 'd': d, 'ko': utc(d, hm, v), 'local': hm, 'h': h, 'a': a, 'v': v, 'city': CITY[v]}
          for i, rnd, d, hm, h, a, v in RWC['knockouts']]
    return {'g': 'm', 'name': RWC['name'], 'host': RWC['host'], 'start': RWC['start'], 'end': RWC['end'],
            'firstKo': matches[0]['ko'], 'format': RWC['format'], 'pools': out_pools, 'matches': matches, 'knockouts': ko,
            'venues': sorted({(v, CITY[v]) for v in TZ}, key=lambda x: (x[1], x[0]))}


# ---------------------------------------------------------------- World Cup scenarios
# The model's win chance is the same one the app shows for every fixture (World Rugby ranking points, +3 at home;
# here only Australia is at home). Scores are then drawn to settle bonus points and points difference, calibrated
# on Tests between ranked teams since 2023: margin about 25.8 x z(p) with a spread of 16.5 points, total points
# 45.5 + 0.45 x margin with a spread of 13, and the chance of 4+ tries rising through 50% at about 28 points.
SIMS, SEED = 20000, 2027
THIRD_SLOTS = [('R16 2', 'CEF'), ('R16 4', 'DEF'), ('R16 5', 'AEF'), ('R16 6', 'BEF')]
BRACKET = {'QF 1': ('R16 2', 'R16 4'), 'QF 2': ('R16 1', 'R16 3'), 'QF 3': ('R16 5', 'R16 6'), 'QF 4': ('R16 7', 'R16 8'),
           'SF 1': ('QF 1', 'QF 2'), 'SF 2': ('QF 3', 'QF 4'), 'Final': ('SF 1', 'SF 2')}
STAGES = [('R16', 'Round of 16'), ('QF', 'Quarter-final'), ('SF', 'Semi-final'), ('Final', 'Final')]


def win_p(a, b, pts):
    adv = 3 if a == RWC['host'] else -3 if b == RWC['host'] else 0
    return 1 / (1 + 10 ** (-(pts.get(a, 50) + adv - pts.get(b, 50)) / 10 * 0.6))


def third_slots(pools):
    """Give the four best third-placed pools a round-of-16 slot each, keeping to the pools each slot allows.
    Where more than one fit is possible, the first in alphabetical order is used."""
    pools = sorted(pools)

    def fit(i, left):
        if i == len(THIRD_SLOTS): return {}
        for p in left:
            if p in THIRD_SLOTS[i][1]:
                rest = fit(i + 1, [x for x in left if x != p])
                if rest is not None: return dict(rest, **{THIRD_SLOTS[i][0]: p})
        return None
    return fit(0, pools) or {s[0]: p for s, p in zip(THIRD_SLOTS, pools)}


def simulate_rwc(rwc, pts, ranks, known, known_ko):
    rng = random.Random(SEED)
    N = statistics.NormalDist()
    pools = {p['p']: [r['t'] for r in p['rows']] for p in rwc['pools']}
    team_pool = {t: p for p, ts in pools.items() for t in ts}
    fixtures = [(m['h'], m['a'], team_pool[m['h']]) for m in rwc['matches']]
    ko = {k['id']: k for k in rwc['knockouts']}

    def score(a, b):
        r = known.get((a, b))
        if r: return r
        p = win_p(a, b, pts)
        a_wins = rng.random() < p
        mu = 25.8 * N.inv_cdf(min(max(p, 0.005), 0.995))
        while True:  # a margin on the right side of the result the model picked
            m = rng.gauss(mu, 16.5)
            if (m >= 1) if a_wins else (m <= -1): break
        m = round(m)
        tot = max(abs(m), 45.5 + 0.45 * abs(m) + rng.gauss(0, 13))
        hi = round((tot + abs(m)) / 2); lo = hi - abs(m)
        sa, sb = (hi, lo) if m > 0 else (lo, hi)
        tri = lambda s: max(0, round(s / 6.8 + rng.gauss(0, 0.6)))
        return sa, sb, tri(sa), tri(sb)

    def pick(a, b):  # knockouts: the model's win chance decides it (extra time and kicks included)
        r = known_ko.get((a, b))
        if r: return a if r[0] > r[1] else b
        return a if rng.random() < win_p(a, b, pts) else b

    count = {t: collections.Counter() for t in team_pool}
    scen = {t: collections.defaultdict(lambda: {'n': 0, 'slot': collections.Counter(), 'stage': {s: collections.Counter() for s, _ in STAGES},
                                                'won': collections.Counter(), 'title': 0}) for t in team_pool}
    champs = collections.Counter()
    for _ in range(SIMS):
        T = {t: [0, 0, 0, 0] for t in team_pool}  # points, points difference, points for, tries
        h2h = {}
        for a, b, _p in fixtures:
            sa, sb, ta, tb = score(a, b)
            for me, op, ms, os_, mt in ((a, b, sa, sb, ta), (b, a, sb, sa, tb)):
                x = T[me]
                x[0] += 4 if ms > os_ else 2 if ms == os_ else (1 if os_ - ms <= 7 else 0)
                x[0] += 1 if mt >= 4 else 0
                x[1] += ms - os_; x[2] += ms; x[3] += mt
            h2h[(a, b)] = sa - sb; h2h[(b, a)] = sb - sa
        place, thirds = {}, []
        for p, ts in pools.items():
            order = sorted(ts, key=lambda t: (-T[t][0], -T[t][1], -T[t][2], -T[t][3], ranks.get(t, 99)))
            for i in range(3):  # two teams level on points: the one who won their match goes first
                a, b = order[i], order[i + 1]
                if T[a][0] == T[b][0] and h2h.get((b, a), 0) > 0 and (i + 2 > 3 or T[order[i + 2]][0] != T[a][0]) and (i == 0 or T[order[i - 1]][0] != T[a][0]):
                    order[i], order[i + 1] = b, a
            place[p] = order
            thirds.append(order[2])
        best = sorted(thirds, key=lambda t: (-T[t][0], -T[t][1], -T[t][2], -T[t][3], ranks.get(t, 99)))[:4]
        slots = third_slots([team_pool[t] for t in best])
        third_in = {s: place[p][2] for s, p in slots.items()}
        seat = {}

        def who(lbl, k):
            if lbl.startswith('Winner Pool '): return place[lbl[-1]][0]
            if lbl.startswith('2nd Pool '): return place[lbl[-1]][1]
            if lbl.startswith('3rd Pool '): return third_in[k]
            return seat[lbl.replace('Winner ', '')]
        path = collections.defaultdict(dict)  # team -> stage -> (match id, opponent, won)
        for k in ['R16 %d' % i for i in range(1, 9)] + ['QF 1', 'QF 2', 'QF 3', 'QF 4', 'SF 1', 'SF 2', 'Final']:
            a, b = (who(ko[k]['h'], k), who(ko[k]['a'], k)) if k.startswith('R16') else (seat[BRACKET[k][0]], seat[BRACKET[k][1]])
            w = pick(a, b)
            seat[k] = w
            stage = 'R16' if k.startswith('R16') else k.split(' ')[0] if k != 'Final' else 'Final'
            path[a][stage] = (k, b, w == a); path[b][stage] = (k, a, w == b)
        champs[seat['Final']] += 1
        for p, order in place.items():
            for i, t in enumerate(order):
                key = str(i + 1) if i < 2 else ('3' if t in best else 'out')
                count[t][key] += 1
                sc = scen[t][key]; sc['n'] += 1
                if t == seat['Final']: sc['title'] += 1
                for st_, _lbl in STAGES:
                    if st_ in path[t]:
                        mid, opp, won = path[t][st_]
                        if st_ == 'R16': sc['slot'][mid] += 1
                        sc['stage'][st_][opp] += 1
                        sc['won'][st_] += won
        for t in team_pool:
            for st_, _ in STAGES:
                if st_ in path[t]: count[t]['reach_' + st_] += 1
            if seat['Final'] == t: count[t]['win'] += 1

    pct = lambda n, d: round(100 * n / d, 1) if d else 0
    LBL = {'1': 'Top Pool %s', '2': 'Second in Pool %s', '3': 'Third in Pool %s, as one of the best four thirds', 'out': 'Out in Pool %s'}
    out = {}
    for t, c in count.items():
        p = team_pool[t]
        sc_out = []
        for key in ('1', '2', '3', 'out'):
            sc = scen[t][key]
            if not sc['n'] or pct(sc['n'], SIMS) < 1: continue
            e = {'k': key, 'lbl': LBL[key] % p, 'p': pct(sc['n'], SIMS), 'title': pct(sc['title'], sc['n'])}
            if key != 'out':
                slot = sc['slot'].most_common(1)[0][0]
                e['slot'] = {'id': slot, 'ko': ko[slot]['ko'], 'city': ko[slot]['city'], 'v': ko[slot]['v'], 'share': pct(sc['slot'][slot], sc['n'])}
                e['stages'] = []
                for st_, lbl in STAGES:
                    reach = sum(sc['stage'][st_].values())
                    if not reach: break
                    e['stages'].append({'s': st_, 'lbl': lbl, 'reach': pct(reach, sc['n']), 'win': pct(sc['won'][st_], reach),
                                        'opps': [[o, pct(n, reach)] for o, n in sc['stage'][st_].most_common(3)]})
            sc_out.append(e)
        out[t] = {'pool': p, 'finish': {k: pct(c[k], SIMS) for k in ('1', '2', '3', 'out')},
                  'reach': {s: pct(c['reach_' + s], SIMS) for s, _ in STAGES}, 'win': pct(c['win'], SIMS), 'scen': sc_out}
    fav = [[t, pct(n, SIMS)] for t, n in champs.most_common()]
    return {'n': SIMS, 'teams': out, 'title': fav, 'ranksAsOf': TODAY,
            'about': 'We play the whole World Cup %s times using the model behind every pick in the app: each team’s chance of winning a match comes from its World Rugby ranking points, with Australia at home. Scores are drawn from how Tests between ranked teams have gone since 2023, to settle bonus points and points difference. Results replace the simulation as they come in.' % '{:,}'.format(SIMS)}


def main():
    RES = pd.concat([load('RugbyResults_AllNations_Detailed.csv', 'm'), load('WomensRugbyResults_Detailed.csv', 'w')])
    RES = RES[RES.home_score.notna() & RES.away_score.notna()]
    FX = json.load(open('fixtures.json', encoding='utf-8'))
    ranks = {l.split('|')[1]: int(l.split('|')[0]) for l in open('rank30.txt', encoding='utf-8') if l.strip()}
    comps = [c for c in (build_tournament(cfg, RES, FX) for cfg in TOURNAMENTS) if c]
    rwc = build_rwc(RES, ranks)
    rank_pts = {l.split('|')[1]: float(l.split('|')[2]) for l in open('rank30.txt', encoding='utf-8') if l.strip()}
    res = RES[(RES.g == 'm') & RES.competition.str.match(RWC['pat'], na=False)]
    known, known_ko = {}, {}
    for r in res.itertuples():  # matches already played count as they finished (pool and knockout kept apart)
        kn = known if r.date < '2027-10-20' else known_ko
        th, ta = (r.home_tries if not pd.isna(r.home_tries) else round(r.home_score / 6.8)), (r.away_tries if not pd.isna(r.away_tries) else round(r.away_score / 6.8))
        kn[(r.home_team, r.away_team)] = (int(r.home_score), int(r.away_score), int(th), int(ta))
        kn.setdefault((r.away_team, r.home_team), (int(r.away_score), int(r.home_score), int(ta), int(th)))
    rwc['sim'] = simulate_rwc(rwc, rank_pts, ranks, known, known_ko)
    # which tournaments each nation is in, and where it sits
    teams = {'m': collections.defaultdict(list), 'w': collections.defaultdict(list)}
    for c in comps:
        if c['fmt'] == 'series':
            for t, x in c['teams'].items():
                teams[c['g']][t].append({'id': c['id'], 'rec': [x['w'], x['d'], x['l']]})
            continue
        for gi, grp in enumerate(c['groups']):
            for x in grp['rows']:
                teams[c['g']][x['t']].append({'id': c['id'], 'grp': gi, 'pos': x['pos'], 'of': len(grp['rows']), 'pts': x['pts'], 'p': x['p']})
    order = {'live': 0, 'next': 1, 'done': 2}
    cid = {c['id']: c for c in comps}
    for g in teams:
        for t in teams[g]:
            teams[g][t].sort(key=lambda e: (order[cid[e['id']]['status']], -int(cid[e['id']]['season'])))
    out = {'asOf': TODAY, 'comps': comps, 'teams': teams, 'rwc': {'m': rwc, 'w': RWC_W}}
    s = json.dumps(out, separators=(',', ':'), ensure_ascii=False, sort_keys=True, default=int)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    open(OUT, 'w', encoding='utf-8').write(s)
    print('tournaments.json: %d bytes, %d tournaments (%s), World Cup %d matches'
          % (len(s), len(comps), ', '.join(c['name'] + ' ' + c['season'] + ' ' + c['status'] for c in comps), len(rwc['matches']) + len(rwc['knockouts'])))


if __name__ == '__main__':
    try:
        main()
    except Exception as e:  # keep yesterday's file rather than stopping the whole site build
        print('::warning::app tournaments feed not rebuilt (%s: %s); keeping the previous file' % (type(e).__name__, e))
