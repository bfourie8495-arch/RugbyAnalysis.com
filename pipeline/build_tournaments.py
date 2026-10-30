"""Build the app's tournaments feed: the latest edition of each major international tournament (tables with
bonus points, or a series record where there is no table), which of them each nation is in and where it sits,
and the next Rugby World Cup (pools, every match with its kick-off in UTC, the knockout path, and live pool
tables once it starts). Writes ../site/app/tournaments.json, served at
https://rugbyanalysis.com/app/tournaments.json for the RugbyAnalysis app.

Runs from build_all.py after update.py. Each tournament picks its latest edition from the results by itself;
the World Cup draw and schedule below are typed in from World Rugby's published schedule (kick-offs are local
to each venue and converted here). If anything goes wrong, the previous file is kept and the run shows a
yellow warning instead of stopping the rest of the site build."""
import json, os, re, datetime, collections
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


def main():
    RES = pd.concat([load('RugbyResults_AllNations_Detailed.csv', 'm'), load('WomensRugbyResults_Detailed.csv', 'w')])
    RES = RES[RES.home_score.notna() & RES.away_score.notna()]
    FX = json.load(open('fixtures.json', encoding='utf-8'))
    ranks = {l.split('|')[1]: int(l.split('|')[0]) for l in open('rank30.txt', encoding='utf-8') if l.strip()}
    comps = [c for c in (build_tournament(cfg, RES, FX) for cfg in TOURNAMENTS) if c]
    rwc = build_rwc(RES, ranks)
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
