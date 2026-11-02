"""Build the app's analysis feed: style of play, pack weights, key players and typical size by shirt
number, for every nation with enough ESPN data. Writes ../site/app/analysis.json, which Cloudflare serves at
https://rugbyanalysis.com/app/analysis.json for the RugbyAnalysis app.

Runs as part of build_all.py after update.py has fetched the day's stats, squads and rankings. The dates move
on by themselves: men's numbers use Tests since 1 January two years back, women's use the most recent year
with full ESPN team stats (a World Cup year). If anything goes wrong, the previous file is kept and the run
shows a yellow warning instead of stopping the rest of the site build."""
import json, collections, statistics as st, os, sys, datetime

OUT = os.path.join('..', 'site', 'app', 'analysis.json')
ALIAS = {'United States of America': 'United States', 'USA': 'United States', 'Czechia': 'Czech Republic',
         'Bosnia-Herzegovina': 'Bosnia and Herzegovina'}
SKIP = {'British and Irish Lions', 'AUNZ XV', 'First Nations & Pasifika XV'}
FWD_POS = {'P', 'H', 'L', 'FL', 'N8', 'prop', 'hooker', 'lock', 'Flanker', 'back-row', 'front-row'}
BACK_POS = {'SH', 'FH', 'C', 'W', 'FB', 'scrum-half', 'Halfback', 'fly-half', 'five-eighth', 'centre', 'wing',
            'Fullback', 'utility back', 'outside back'}
POSN = {1: 'Loosehead prop', 2: 'Hooker', 3: 'Tighthead prop', 4: 'Lock', 5: 'Lock', 6: 'Blindside flanker',
        7: 'Openside flanker', 8: 'Number 8', 9: 'Scrum-half', 10: 'Fly-half', 11: 'Left wing', 12: 'Inside centre',
        13: 'Outside centre', 14: 'Right wing', 15: 'Full-back'}
GRP = {1: 'Prop', 3: 'Prop', 2: 'Hooker', 4: 'Lock', 5: 'Lock', 6: 'Back row', 7: 'Back row', 8: 'Back row',
       9: 'Scrum-half', 10: 'Fly-half', 11: 'Wing', 14: 'Wing', 12: 'Centre', 13: 'Centre', 15: 'Full-back'}
PK = ['tackles', 'missedTackles', 'metres', 'runs', 'cleanBreaks', 'defendersBeaten', 'offload', 'tries', 'tryAssists',
      'points', 'turnoversConceded', 'penaltiesConceded', 'kicksFromHand', 'lineoutsWon', 'yellowCards', 'redCards',
      'conversionGoals', 'penaltyGoals', 'passes']
K = {k: i for i, k in enumerate(PK)}
TK = ["tackles", "missedTackles", "cleanBreaks", "defendersBeaten", "offload", "metres", "runs", "passes",
      "kicksFromHand", "possession", "territory", "penaltiesConceded", "totalFreeKicksConceded", "scrumsTotal",
      "scrumsWon", "totalLineouts", "lineoutsWon", "lineoutWonSteal", "maulsTotal", "maulsWon", "rucksTotal",
      "rucksWon", "turnoversConceded", "turnoverKnockOn", "yellowCards", "redCards", "tries"]
T = {k: i for i, k in enumerate(TK)}

A = json.load(open('espn_athletes.json', encoding='utf-8'))
R = json.load(open('espn_rosters.json', encoding='utf-8'))
E = json.load(open('espn_tests.json', encoding='utf-8'))
PL = json.load(open('players.json', encoding='utf-8'))

# the data's own latest date (never in the future), and the rolling windows that follow from it
TODAY = datetime.date.today().isoformat()
AS_OF = max(v[1] for v in R.values() if v[1] <= TODAY)
_wyears = sorted({e[2][:4] for e in E if e[0] == '289237' or ' Women' in e[3] + e[4]})
WIN = {'m': '%d-01-01' % (int(AS_OF[:4]) - 2),
       'w': (_wyears[-1] if _wyears else str(int(AS_OF[:4]) - 1)) + '-01-01'}


def norm(t):
    w = t.endswith(' Women')
    t = t.replace(' Women', '')
    return ALIAS.get(t, t), w


def is_fwd(j, pos, aid):
    if 1 <= j <= 8: return True
    if 9 <= j <= 15: return False
    if pos in FWD_POS: return True
    if pos in BACK_POS: return False
    p = A.get(aid, {}).get('pos', '')
    return p in FWD_POS


# ---------- per-team match records from squads ----------
games = {'m': collections.defaultdict(list), 'w': collections.defaultdict(list)}
for eid, (lg, date, sides) in sorted(R.items(), key=lambda x: x[1][1]):
    if len(sides) != 2: continue
    (_, t0, p0), (_, t1, p1) = sides
    n0, w0 = norm(t0); n1, w1 = norm(t1)
    g = 'w' if (w0 or w1 or lg == '289237') else 'm'
    if n0 in SKIP or n1 in SKIP: continue
    for team, opp, ps in ((n0, n1, p0), (n1, n0, p1)):
        rec = {'eid': eid, 'd': date, 'opp': opp, 'xv': {}, 'bench': [], 'cap': None, 'st': [0] * len(PK), 'hasSt': False, 'pl': []}
        for row in ps:
            aid, j, sub, cap, pos = row[:5]
            stv = row[5] if len(row) > 5 else None
            if not aid or not (1 <= j <= 23): continue
            if j <= 15: rec['xv'][j] = aid
            else: rec['bench'].append((j, aid, pos))
            if cap: rec['cap'] = aid
            played = j <= 15 or sub or (stv and any(stv))
            if stv and any(v for v in stv if v):
                rec['hasSt'] = True
                for k, v in enumerate(stv): rec['st'][k] += v or 0
            if played: rec['pl'].append((aid, j, stv if stv and any(v for v in stv if v) else None))
        games[g][team].append(rec)

# ---------- team-level ESPN stats (possession, territory, set piece) ----------
tstats = {'m': collections.defaultdict(list), 'w': collections.defaultdict(list)}
tdates = {'m': collections.defaultdict(list), 'w': collections.defaultdict(list)}
for e in E:
    lg, eid, d, h, a, hs, as_, sh, sa = e
    hn, hw = norm(h); an, aw = norm(a)
    g = 'w' if (hw or aw or lg == '289237') else 'm'
    if d < WIN[g] or d > AS_OF: continue
    tstats[g][hn].append(sh); tstats[g][an].append(sa)
    tdates[g][hn].append(d); tdates[g][an].append(d)


def mean(xs):
    xs = [x for x in xs if x is not None]
    return sum(xs) / len(xs) if xs else None


def team_style(g, team):
    ts = tstats[g].get(team, [])
    recs = [r for r in games[g][team] if WIN[g] <= r['d'] <= AS_OF and r['hasSt']]
    if len(ts) >= 4:
        # ESPN team totals: the most complete source (top-tier competitions)
        n = len(ts)
        s = lambda k: mean([x[T[k]] for x in ts])
        tk, ms = s('tackles'), s('missedTackles')
        out = {'n': n, 'src': 'team',
               'kicks': s('kicksFromHand'), 'passes': s('passes'), 'carries': mean([x[T['runs']] for x in ts if x[T['runs']]]),
               'metres': s('metres'), 'beaten': s('defendersBeaten'), 'offloads': s('offload'), 'breaks': s('cleanBreaks'),
               'tackles': tk, 'tackleSucc': 100 * tk / (tk + ms) if tk + ms else None,
               'pens': s('penaltiesConceded'), 'tries': s('tries')}
        pos = mean([x[T['possession']] for x in ts if x[T['possession']]])
        ter = mean([x[T['territory']] for x in ts if x[T['territory']]])
        sc_t = sum(x[T['scrumsTotal']] or 0 for x in ts); sc_w = sum(x[T['scrumsWon']] or 0 for x in ts)
        lo_t = sum(x[T['totalLineouts']] or 0 for x in ts); lo_w = sum(x[T['lineoutsWon']] or 0 for x in ts)
        out['poss'] = 100 * pos if pos else None
        out['terr'] = 100 * ter if ter else None
        out['scrum'] = 100 * sc_w / sc_t if sc_t else None
        out['lineout'] = 100 * lo_w / lo_t if lo_t else None
        out['since'] = min(tdates[g][team])
        return out
    if len(recs) < 4: return None
    # otherwise add up the players' stats from each Test
    n = len(recs)
    s = lambda k: sum(r['st'][K[k]] for r in recs) / n
    tk, ms = s('tackles'), s('missedTackles')
    return {'n': n, 'src': 'players', 'since': recs[0]['d'],
            'kicks': s('kicksFromHand'), 'passes': s('passes'), 'carries': s('runs'), 'metres': s('metres'),
            'beaten': s('defendersBeaten'), 'offloads': s('offload'), 'breaks': s('cleanBreaks'),
            'tackles': tk, 'tackleSucc': 100 * tk / (tk + ms) if tk + ms else None,
            'pens': s('penaltiesConceded'), 'tries': s('tries')}


def pack_of(rec):
    ws = [A.get(rec['xv'].get(j, ''), {}).get('w') for j in range(1, 9)]
    if any(not w for w in ws): return None
    return sum(ws)


def team_pack(g, team):
    recs = [r for r in games[g][team] if r['d'] <= AS_OF]
    if not recs: return None
    last = None
    for r in reversed(recs):
        if pack_of(r): last = r; break
    if not last: return None
    fw = []
    for j in range(1, 9):
        aid = last['xv'][j]; a = A.get(aid, {})
        fw.append({'j': j, 'n': a.get('n') or a.get('fn') or '?', 'w': a.get('w'), 'h': a.get('h'), 'c': 1 if last['cap'] == aid else 0})
    backs = [A.get(last['xv'].get(j, ''), {}).get('w') for j in range(9, 16)]
    backs = [b for b in backs if b]
    bf = sum(1 for (j, aid, pos) in last['bench'] if is_fwd(j, pos, aid))
    bn = len(last['bench'])
    # yearly average starting pack (trend)
    yr = collections.defaultdict(list)
    for r in recs:
        p = pack_of(r)
        if p: yr[r['d'][:4]].append(p)
    trend = [[int(y), round(sum(v) / len(v))] for y, v in sorted(yr.items()) if int(y) >= 2012 and len(v) >= 2]
    rec_packs = [pack_of(r) for r in recs if WIN[g] <= r['d'] and pack_of(r)]
    cap = A.get(last['cap'], {}).get('n') if last['cap'] else None
    return {
        'd': last['d'], 'opp': last['opp'], 'total': pack_of(last), 'fw': fw,
        'backsAvg': round(sum(backs) / len(backs), 1) if len(backs) >= 6 else None,
        'bench': [bf, bn - bf] if bn >= 6 else None, 'trend': trend,
        'avgRecent': round(sum(rec_packs) / len(rec_packs)) if len(rec_packs) >= 3 else None,
        'nRecent': len(rec_packs), 'captain': cap,
    }


def key_players(g, team):
    recs = [r for r in games[g][team] if WIN[g] <= r['d'] <= AS_OF]
    agg = {}
    for r in recs:
        for aid, j, stv in r['pl']:
            q = agg.setdefault(aid, {'apps': 0, 'sn': 0, 'st': [0] * len(PK), 'jer': collections.Counter()})
            q['apps'] += 1
            if j <= 15: q['jer'][j] += 1
            if stv:
                q['sn'] += 1
                for k, v in enumerate(stv): q['st'][k] += v or 0
    if not agg: return []
    # caps from players.json (Wikipedia), matched by name
    capby = {}
    for row in PL['p']:
        if row[2] == g and row[12] is not None: capby.setdefault(row[0], row[12])

    def nm(aid):
        a = A.get(aid, {}); return a.get('n') or a.get('fn') or '?'

    def pos(aid):
        q = agg[aid]
        if q['jer']: return GRP[q['jer'].most_common(1)[0][0]]
        p = A.get(aid, {}).get('pos', '')
        return {'prop': 'Prop', 'hooker': 'Hooker', 'lock': 'Lock', 'Flanker': 'Back row', 'back-row': 'Back row',
                'scrum-half': 'Scrum-half', 'fly-half': 'Fly-half', 'centre': 'Centre', 'wing': 'Wing', 'Fullback': 'Full-back'}.get(p, 'Replacement')

    used = set()
    cards = []

    def pick(kind, label, score, fmt, minsn=3, need=lambda a: True):
        cand = [a for a, q in agg.items() if q['sn'] >= minsn and need(a) and score(a) > 0]
        cand.sort(key=lambda a: (-score(a), -agg[a]['apps']))
        for a in cand:
            if a in used: continue
            used.add(a)
            v, sub = fmt(a)
            cards.append({'k': kind, 'l': label, 'n': nm(a), 'p': pos(a), 'v': v, 'sub': sub})
            return

    st_ = lambda a, k: agg[a]['st'][K[k]]
    pg = lambda a, k: st_(a, k) / agg[a]['sn']
    pick('tries', 'Top try scorer', lambda a: st_(a, 'tries') + st_(a, 'metres') / 1e5,
         lambda a: (str(int(st_(a, 'tries'))), 'tries in %d Tests' % agg[a]['sn']), minsn=1)
    pick('metres', 'Gainline breaker', lambda a: pg(a, 'metres'),
         lambda a: ('%d m' % round(pg(a, 'metres')), 'carried a game, %d defenders beaten' % st_(a, 'defendersBeaten')))
    pick('tackles', 'Tackle machine', lambda a: pg(a, 'tackles'),
         lambda a: ('%.1f' % pg(a, 'tackles'), 'tackles a game, %d%% made' % round(100 * st_(a, 'tackles') / max(1, st_(a, 'tackles') + st_(a, 'missedTackles')))))
    pick('points', 'Points machine', lambda a: st_(a, 'points'),
         lambda a: (str(int(st_(a, 'points'))), 'points: %d conversions, %d penalties' % (st_(a, 'conversionGoals'), st_(a, 'penaltyGoals'))), minsn=1)
    pick('beaten', 'Hardest to stop', lambda a: pg(a, 'defendersBeaten'),
         lambda a: ('%.1f' % pg(a, 'defendersBeaten'), 'defenders beaten a game'))
    pick('lineout', 'Lineout general', lambda a: st_(a, 'lineoutsWon'),
         lambda a: (str(int(st_(a, 'lineoutsWon'))), 'lineouts won in %d Tests' % agg[a]['sn']), minsn=3)
    # most capped in this window's squad
    capc = [(capby.get(nm(a)), a) for a in agg if capby.get(nm(a))]
    capc.sort(key=lambda x: -x[0])
    for c, a in capc:
        if a in used: continue
        used.add(a)
        cards.append({'k': 'caps', 'l': 'Most experienced', 'n': nm(a), 'p': pos(a), 'v': str(c), 'sub': 'Test caps'})
        break
    return cards


def typical_sizes(g, teams):
    by = collections.defaultdict(lambda: {'w': [], 'h': []})
    for t in teams:
        for r in games[g][t]:
            if not (WIN[g] <= r['d'] <= AS_OF): continue
            for j, aid in r['xv'].items():
                a = A.get(aid, {})
                if a.get('w'): by[j]['w'].append(a['w'])
                if a.get('h'): by[j]['h'].append(a['h'])
    return {j: [round(st.mean(v['w'])), round(st.mean(v['h']))] for j, v in sorted(by.items()) if len(v['w']) >= 20}


METRICS = [  # key, label, unit, decimals, higherIsGood (None = neutral style measure), group
    ('poss', 'Possession', '%', 0, None, 'ball'),
    ('terr', 'Territory', '%', 0, True, 'ball'),
    ('kicks', 'Kicks from hand', '', 1, None, 'ball'),
    ('passes', 'Passes', '', 0, None, 'ball'),
    ('carries', 'Carries', '', 0, None, 'attack'),
    ('metres', 'Metres carried', 'm', 0, True, 'attack'),
    ('beaten', 'Defenders beaten', '', 1, True, 'attack'),
    ('offloads', 'Offloads', '', 1, None, 'attack'),
    ('tries', 'Tries', '', 1, True, 'attack'),
    ('tackles', 'Tackles made', '', 0, None, 'defence'),
    ('tackleSucc', 'Tackle success', '%', 0, True, 'defence'),
    ('pens', 'Penalties conceded', '', 1, False, 'defence'),
    ('scrum', 'Scrums won', '%', 0, True, 'set'),
    ('lineout', 'Lineouts won', '%', 0, True, 'set'),
]


def build(g, ranked):
    teams = [t for t in games[g] if games[g][t]]
    style = {t: team_style(g, t) for t in teams}
    style = {t: s for t, s in style.items() if s}
    pack = {t: team_pack(g, t) for t in teams}
    pack = {t: p for t, p in pack.items() if p}
    # comparison group: ranked teams with style data (top 12 men, top 10 women), else everyone with data
    top = [t for t in ranked if t in style][: (12 if g == 'm' else 10)]
    grp = top if len(top) >= 6 else list(style)
    out = {}
    for t in set(style) | set(pack):
        s = style.get(t)
        o = {}
        if s:
            rows = []
            zs = {}
            for k, lab, unit, dec, good, sec in METRICS:
                v = s.get(k)
                if v is None: continue
                gv = [style[x][k] for x in grp if style[x].get(k) is not None]
                if len(gv) < 4: continue
                lo, hi = min(gv + [v]), max(gv + [v])
                avg = sum(gv) / len(gv)
                sd = st.pstdev(gv) or 1
                zs[k] = (v - avg) / sd
                rank = 1 + sum(1 for x in gv if x > v) if t in grp else None
                rows.append({'k': k, 'l': lab, 'u': unit, 'v': round(v, dec), 'avg': round(avg, dec), 'sec': sec,
                             'pct': round(100 * (v - lo) / (hi - lo)) if hi > lo else 50,
                             'apct': round(100 * (avg - lo) / (hi - lo)) if hi > lo else 50,
                             'good': good, 'rank': rank, 'of': len(gv)})
            o['style'] = {'n': s['n'], 'since': s['since'], 'src': s['src'], 'rows': rows}
            o['style'].update(describe(t, s, zs, pack.get(t), g))
        if t in pack: o['pack'] = pack[t]
        o['keys'] = key_players(g, t)
        o['keysN'] = len({r['eid'] for r in games[g][t] if WIN[g] <= r['d'] <= AS_OF and r['hasSt']})
        out[t] = o
    # pack ranks among group (latest total and recent average)
    pg = [t for t in (top if len(top) >= 6 else list(pack)) if t in pack and pack[t].get('avgRecent')]
    for t in pack:
        p = pack[t]
        if p.get('avgRecent') and t in pg:
            p['rank'] = 1 + sum(1 for x in pg if pack[x]['avgRecent'] > p['avgRecent'])
            p['of'] = len(pg)
    grp_avg = round(sum(pack[x]['avgRecent'] for x in pg) / len(pg)) if pg else None
    smap = [{'t': t, 'x': round(style[t]['kicks'], 1), 'y': round(style[t]['passes'])} for t in grp]
    return out, grp, grp_avg, smap


def describe(t, s, z, pk, g):
    ppk = s['passes'] / s['kicks'] if s['kicks'] else 0
    tags = []
    zk, zp = z.get('kicks', 0), z.get('passes', 0)
    if zk >= 0.6 and zp <= 0.3: head = ('Territory first', 'They kick for position and play in the right areas, rather than keeping the ball.')
    elif zp >= 0.6 and zk <= 0.3: head = ('Ball in hand', 'They keep the ball and build phases, kicking less than most.')
    elif zk >= 0.6 and zp >= 0.6: head = ('High tempo', 'Plenty of kicking and passing: a busy, high-involvement game.')
    elif zk <= -0.6 and zp <= -0.6: head = ('Direct and tight', 'Fewer kicks and fewer passes: they carry close and keep it simple.')
    else: head = ('Balanced', 'A mix of kicking for territory and playing with ball in hand.')
    cand = [
        ('offloads', 0.7, 'Offload game', 'Keeps the ball alive in the tackle'),
        ('beaten', 0.7, 'Evasive runners', 'Beats defenders more than most'),
        ('metres', 0.7, 'Gainline winners', 'Big metres after contact'),
        ('tackleSucc', 0.7, 'Tight defence', 'Rarely misses a tackle'),
        ('tackles', 0.8, 'Defend a lot', 'Spends long spells without the ball'),
        ('scrum', 0.7, 'Strong scrum', 'Wins its own scrum ball reliably'),
        ('lineout', 0.7, 'Reliable lineout', 'Secure ball off the top'),
        ('terr', 0.7, 'Plays in the right areas', 'Spends most of the game in the other half'),
        ('tries', 0.7, 'Try scorers', 'Crosses the line more than most'),
    ]
    for k, thr, lab, why in cand:
        if z.get(k, 0) >= thr: tags.append({'t': lab, 'why': why, 'z': z[k]})
    if z.get('pens', 0) <= -0.7: tags.append({'t': 'Disciplined', 'why': 'Concedes fewer penalties than most', 'z': -z['pens']})
    if z.get('pens', 0) >= 0.8: tags.append({'t': 'Gives away penalties', 'why': 'Concedes more penalties than most', 'z': z['pens']})
    if z.get('poss', 0) <= -0.7 and z.get('terr', 0) >= -0.2: tags.append({'t': 'Happy without the ball', 'why': 'Less possession, but still plays in the right areas', 'z': -z['poss']})
    if z.get('tackleSucc', 0) <= -0.8: tags.append({'t': 'Misses tackles', 'why': 'Misses more tackles than most', 'z': -z['tackleSucc']})
    tags.sort(key=lambda x: -x['z'])
    tags = [{'t': x['t'], 'why': x['why']} for x in tags[:3]]
    summ = '%s kick %.0f times and pass %.0f times a game: %.1f passes for every kick.' % (t, s['kicks'], s['passes'], ppk)
    return {'head': head[0], 'headWhy': head[1], 'tags': tags, 'summary': summ, 'ppk': round(ppk, 1)}


def ranked_lists():
    men = [l.split('|')[1] for l in open('rank30.txt', encoding='utf-8') if l.strip()]
    women = [n for n, _ in sorted(json.load(open('rankw.json', encoding='utf-8')).items(), key=lambda x: x[1][0])]
    return {'m': men, 'w': women}


def main():
    ranked = ranked_lists()
    out = {'asOf': AS_OF, 'win': WIN}
    for g in ('m', 'w'):
        teams, grp, gavg, smap = build(g, ranked[g])
        out[g] = {'teams': teams, 'group': grp, 'packAvg': gavg, 'map': smap,
                  'sizes': typical_sizes(g, [t for t in ranked[g][:12] if t in games[g]])}
    s = json.dumps(out, separators=(',', ':'), ensure_ascii=False, sort_keys=True)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    open(OUT, 'w', encoding='utf-8').write(s)
    print('analysis.json: %d bytes, %d men\'s and %d women\'s teams, data to %s'
          % (len(s), len(out['m']['teams']), len(out['w']['teams']), AS_OF))


if __name__ == '__main__':
    try:
        main()
    except Exception as e:  # keep yesterday's file rather than stopping the whole site build
        print('::warning::app analysis feed not rebuilt (%s: %s); keeping the previous file' % (type(e).__name__, e))
