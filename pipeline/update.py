"""Daily data refresh for RugbyAnalysis.com.

Pulls new results, fixtures, team stats, line-ups and player profiles from ESPN's
public JSON feeds, the World Rugby rankings, and (weekly) current squads and caps
from Wikipedia. Everything is appended to the data files in this folder; the build
scripts then regenerate the site. Each source is wrapped so one failure never
stops the others: the site still rebuilds with whatever data it has.
"""
import json, os, re, sys, time, datetime as dt, unicodedata, traceback
from zoneinfo import ZoneInfo
import requests
import pandas as pd

HERE = os.path.dirname(os.path.abspath(__file__))
os.chdir(HERE)
S = requests.Session()
S.headers['User-Agent'] = 'RugbyAnalysis.com data refresh (https://rugbyanalysis.com)'
SITE = 'https://site.api.espn.com/apis/site/v2/sports/rugby/'
CORE = 'https://sports.core.api.espn.com/v2/sports/rugby/'
TODAY = dt.date.today()
LOOKBACK = int(os.environ.get('LOOKBACK_DAYS', '21'))
AHEAD = int(os.environ.get('AHEAD_DAYS', '150'))
LOG = []


def log(*a):
    s = ' '.join(str(x) for x in a)
    print(s, flush=True)
    LOG.append(s)


FAILS = {}


def get(url, tries=3):
    host = url.split('/')[2]
    if FAILS.get(host, 0) >= 5:   # host looks down: skip quickly, keep the existing data
        return None
    for k in range(tries):
        try:
            r = S.get(url, timeout=30)
            if r.status_code == 200:
                FAILS[host] = 0
                return r.json()
            if r.status_code in (400, 404):
                return None
        except Exception as e:
            if k == tries - 1:
                log('fetch failed', url, e)
        time.sleep(2 * (k + 1))
    FAILS[host] = FAILS.get(host, 0) + 1
    return None


def jload(f, default):
    try:
        return json.load(open(f, encoding='utf-8'))
    except FileNotFoundError:
        return default


def jsave(f, obj):
    tmp = f + '.tmp'
    json.dump(obj, open(tmp, 'w', encoding='utf-8'), ensure_ascii=False, separators=(',', ':'))
    os.replace(tmp, f)


# ---------------------------------------------------------------- shared lookups
MEN_CSV = 'RugbyResults_AllNations_Detailed.csv'
WOMEN_CSV = 'WomensRugbyResults_Detailed.csv'
T10 = ['Argentina', 'Australia', 'England', 'France', 'Ireland', 'Italy', 'New Zealand', 'Scotland', 'South Africa', 'Wales']
NAMES = set(T10) | set(json.load(open('others.json', encoding='utf-8')))
ALIAS = {'United States of America': 'United States', 'USA': 'United States', 'Bosnia-Herzegovina': 'Bosnia and Herzegovina',
         'Czechia': 'Czech Republic', 'Korea Republic': 'South Korea', "Cote d'Ivoire": 'Ivory Coast', 'Hong Kong China': 'Hong Kong',
         'Chinese Taipei': 'Taiwan', 'Russian Federation': 'Russia', 'Türkiye': 'Turkey', 'Turkiye': 'Turkey'}
TZ = {'England': 'Europe/London', 'Scotland': 'Europe/London', 'Wales': 'Europe/London', 'Ireland': 'Europe/Dublin', 'Northern Ireland': 'Europe/London',
      'France': 'Europe/Paris', 'Italy': 'Europe/Rome', 'Spain': 'Europe/Madrid', 'Portugal': 'Europe/Lisbon', 'Georgia': 'Asia/Tbilisi', 'Romania': 'Europe/Bucharest',
      'Netherlands': 'Europe/Amsterdam', 'Belgium': 'Europe/Brussels', 'Germany': 'Europe/Berlin', 'South Africa': 'Africa/Johannesburg', 'Namibia': 'Africa/Windhoek',
      'New Zealand': 'Pacific/Auckland', 'Australia': 'Australia/Sydney', 'Fiji': 'Pacific/Fiji', 'Samoa': 'Pacific/Apia', 'Tonga': 'Pacific/Tongatapu',
      'Japan': 'Asia/Tokyo', 'Hong Kong': 'Asia/Hong_Kong', 'Argentina': 'America/Argentina/Buenos_Aires', 'Uruguay': 'America/Montevideo', 'Chile': 'America/Santiago',
      'Brazil': 'America/Sao_Paulo', 'Paraguay': 'America/Asuncion', 'United States': 'America/New_York', 'USA': 'America/New_York', 'Canada': 'America/Toronto',
      'Kenya': 'Africa/Nairobi', 'Uganda': 'Africa/Kampala', 'Zimbabwe': 'Africa/Harare'}
VENUE_COUNTRY_FIX = {'USA': 'United States', 'United States of America': 'United States', 'UK': 'England'}


def nat(name):
    women = name.endswith(' Women')
    n = name.replace(' Women', '')
    return ALIAS.get(n, n), women


def local_date(iso, country):
    t = dt.datetime.fromisoformat(iso.replace('Z', '+00:00'))
    tz = TZ.get(country)
    return (t.astimezone(ZoneInfo(tz)) if tz else t).date().isoformat()


# ---------------------------------------------------------------- 1. Tests
TEST_LEAGUES = {'164205': 'Rugby World Cup', '180659': 'Six Nations Championship', '244293': 'Rugby Championship',
                '17567': 'Nations Championship', '289234': 'Test match', '289237': "Women's Rugby World Cup", '289274': 'Tri Nations'}
SK = ['tackles', 'missedTackles', 'cleanBreaks', 'defendersBeaten', 'offload', 'metres', 'runs', 'passes', 'kicksFromHand', 'possession', 'territory',
      'penaltiesConceded', 'totalFreeKicksConceded', 'scrumsTotal', 'scrumsWon', 'totalLineouts', 'lineoutsWon', 'lineoutWonSteal', 'maulsTotal', 'maulsWon',
      'rucksTotal', 'rucksWon', 'turnoversConceded', 'turnoverKnockOn', 'yellowCards', 'redCards', 'tries']
PK = ['tackles', 'missedTackles', 'metres', 'runs', 'cleanBreaks', 'defendersBeaten', 'offload', 'tries', 'tryAssists', 'points', 'turnoversConceded',
      'penaltiesConceded', 'kicksFromHand', 'lineoutsWon', 'yellowCards', 'redCards', 'conversionGoals', 'penaltyGoals', 'passes']


def team_stats(t):
    o = {}
    for g in t.get('statistics') or []:
        for x in g.get('stats') or []:
            try:
                o[x['name']] = float(x.get('value', x.get('displayValue')))
            except (TypeError, ValueError):
                pass
    return o


def scoreboard(lg, start, end):
    """ESPN accepts a year (YYYY) or month (YYYYMM) in `dates`, not a range, so walk the months."""
    out, seen, y, m = [], set(), start.year, start.month
    while (y, m) <= (end.year, end.month):
        j = get(f'{SITE}{lg}/scoreboard?dates={y}{m:02d}&limit=1000')
        for e in (j or {}).get('events') or []:
            if e['id'] not in seen:
                seen.add(e['id']); out.append(e)
        y, m = (y + 1, 1) if m == 12 else (y, m + 1)
    return out


def update_tests(rank_pts):
    men = pd.read_csv(MEN_CSV, sep=';', dtype=str, keep_default_na=False)
    wom = pd.read_csv(WOMEN_CSV, sep=';', dtype=str, keep_default_na=False)
    stats = jload('espn_tests.json', [])
    rost = jload('espn_rosters.json', {})
    ath = jload('espn_athletes.json', {})
    seen = set(jload('espn_seen.json', [])) | set(rost) | {r[1] for r in stats}
    have_stats = {r[1] for r in stats}
    fixtures, added = [], {'m': 0, 'w': 0}
    rank_w = {n: v[1] for n, v in jload('rankw.json', {}).items()}  # written by update_rankings just before
    new_ath = set()
    start, end = TODAY - dt.timedelta(days=LOOKBACK), TODAY + dt.timedelta(days=AHEAD)

    def exists(df, d, h, a):
        d0 = dt.date.fromisoformat(d)
        for k in range(-1, 2):
            dd = (d0 + dt.timedelta(days=k)).strftime('%Y/%m/%d')
            sub = df[df.date == dd]
            if ((sub.home_team == h) & (sub.away_team == a)).any() or ((sub.home_team == a) & (sub.away_team == h)).any():
                return True
        return False

    for lg, label in TEST_LEAGUES.items():
        for e in scoreboard(lg, start, end):
            eid = e['id']
            comp = e['competitions'][0]
            st = (e.get('status') or {}).get('type') or {}
            cs = comp.get('competitors') or []
            if len(cs) != 2:
                continue
            home = next((c for c in cs if c.get('homeAway') == 'home'), cs[0])
            away = next((c for c in cs if c.get('homeAway') == 'away'), cs[1])
            hn, hw = nat(home['team']['displayName'])
            an, aw = nat(away['team']['displayName'])
            women = hw or aw or lg == '289237'
            venue = comp.get('venue') or {}
            vcountry = VENUE_COUNTRY_FIX.get((venue.get('address') or {}).get('country'), (venue.get('address') or {}).get('country')) or hn
            if st.get('state') == 'pre':
                rp = rank_w if women else rank_pts
                if hn in NAMES and an in NAMES and (hn in rp or an in rp):
                    rh, ra = rp.get(hn, 50), rp.get(an, 50)
                    homeadv = 0 if comp.get('neutralSite') else 3
                    p = 1 / (1 + 10 ** (-(rh + homeadv - ra) / 10 * 0.6))
                    city = (venue.get('address') or {}).get('city') or ''
                    fixtures.append({'ko': e['date'][:16] + ':00Z' if comp.get('timeValid', True) else None, 'd': e['date'][:10], 'h': hn, 'a': an,
                                     'c': label, 'v': ', '.join(x for x in [venue.get('fullName'), city] if x) or 'Venue TBC',
                                     'p': round(p, 2), 'tz': TZ.get(vcountry, 'UTC'), **({'g': 'w'} if women else {})})
                continue
            if not st.get('completed') or eid in seen:
                continue
            s = get(f'{SITE}{lg}/summary?event={eid}')
            if not s:
                continue
            hs, as_ = int(float(home.get('score') or 0)), int(float(away.get('score') or 0))
            if hs == 0 and as_ == 0:  # cancelled or abandoned
                seen.add(eid)
                continue
            gi = s.get('gameInfo') or {}
            gv = gi.get('venue') or {}
            if gv.get('fullName'):
                venue = {'fullName': gv['fullName'], 'address': gv.get('address') or venue.get('address') or {}}
                c2 = (venue['address'] or {}).get('country')
                vcountry = VENUE_COUNTRY_FIX.get(c2, c2) or vcountry
            date = local_date(e['date'], vcountry)
            bx = {t.get('homeAway'): team_stats(t) for t in (s.get('boxscore') or {}).get('teams') or []}
            hv, av = bx.get('home', {}), bx.get('away', {})
            # results CSV
            if hn in NAMES and an in NAMES:
                df = wom if women else men
                if not exists(df, date, hn, an):
                    ref = ((gi.get('officials') or [{}])[0] or {}).get('displayName', '')
                    g = lambda v, k: str(int(v[k])) if k in v else ''
                    row = {c: '' for c in df.columns}
                    row.update(date=date.replace('-', '/'), home_team=hn, away_team=an, home_score=str(hs), away_score=str(as_),
                               competition=f"{date[:4]} {label}" if label not in ('Test match', "Women's Rugby World Cup") else f"{date[:4]} Women's Rugby World Cup" if lg == '289237' else f"{date[:4]} {'women' if women else 'men'}'s rugby union internationals",
                               stadium=venue.get('fullName', ''), city=(venue.get('address') or {}).get('city', ''), country=vcountry,
                               neutral='FALSE' if vcountry == hn else 'TRUE', world_cup='TRUE' if lg in ('164205', '289237') else 'FALSE',
                               home_tries=g(hv, 'tries'), away_tries=g(av, 'tries'), home_yellow=g(hv, 'yellowCards'), away_yellow=g(av, 'yellowCards'),
                               home_red=g(hv, 'redCards'), away_red=g(av, 'redCards'), referee=ref, attendance=str(gi.get('attendance') or '') if gi.get('attendance') else '')
                    if women:
                        wom = pd.concat([wom, pd.DataFrame([row])], ignore_index=True)
                    else:
                        men = pd.concat([men, pd.DataFrame([row])], ignore_index=True)
                    added['w' if women else 'm'] += 1
                    log('new Test', date, hn, hs, '-', as_, an)
            # team stats
            if hv.get('tackles') and eid not in have_stats:
                stats.append([lg, eid, date, home['team']['displayName'], away['team']['displayName'], hs, as_,
                              [hv.get(k) for k in SK], [av.get(k) for k in SK]])
            # line-ups
            sides = []
            for r in s.get('rosters') or []:
                ps = []
                for x in r.get('roster') or []:
                    a = x.get('athlete') or {}
                    if not a.get('id'):
                        continue
                    stx = {z['name']: z.get('value') for z in x.get('stats') or []}
                    ps.append([a['id'], int(x.get('jersey') or 0), 1 if x.get('subbedIn') else 0, 1 if x.get('captain') else 0,
                               (x.get('position') or {}).get('abbreviation', ''), [stx.get(k) for k in PK] if stx else 0])
                    if a['id'] not in ath:
                        new_ath.add(a['id'])
                        ath[a['id']] = {'n': a.get('displayName')}
                sides.append([r.get('homeAway'), (r.get('team') or {}).get('displayName'), ps])
            if sides and any(len(sd[2]) >= 15 for sd in sides):
                rost[eid] = [lg, date, sides]
            seen.add(eid)
    # player profiles for new names
    for aid in sorted(new_ath):
        a = get(f'{CORE}athletes/{aid}')
        if not a:
            continue
        ath[aid].update(w=round(a['weight'] * 0.4536, 1) if a.get('weight') else None, h=round(a['height'] * 2.54) if a.get('height') else None,
                        b=(a.get('dateOfBirth') or '')[:10] or None, pos=(a.get('position') or {}).get('displayName'),
                        bp=(a.get('birthPlace') or {}).get('country'), fn=a.get('fullName'))
    for df, f in ((men, MEN_CSV), (wom, WOMEN_CSV)):
        df.to_csv(f, sep=';', index=False)  # new rows are appended; the build sorts by date
    jsave('espn_tests.json', stats)
    jsave('espn_rosters.json', rost)
    jsave('espn_athletes.json', ath)
    jsave('espn_seen.json', sorted(seen))
    if fixtures:
        # keep hand-written labels (e.g. "Bledisloe Cup · 1st Test") for fixtures already listed
        old = {(f.get('d') or (f.get('ko') or '')[:10], f['h'], f['a']): f for f in jload('fixtures.json', [])}
        for f in fixtures:
            o = old.pop((f['d'], f['h'], f['a']), None)
            if o and o.get('c') and f['c'] in ('Test match', 'Nations Championship', 'Rugby Championship', 'Six Nations Championship', "Women's Rugby World Cup"):
                f['c'] = o['c']
        # fixtures added by hand ("manual": true, e.g. women's Tests the ESPN feed doesn't carry) stay until they are played
        fixtures += [o for o in old.values() if o.get('manual') and (o.get('d') or o['ko'][:10]) >= TODAY.isoformat()]
        fixtures.sort(key=lambda f: f.get('d') or f['ko'][:10])
        jsave('fixtures.json', fixtures)
    log(f"Tests: {added['m']} men's and {added['w']} women's results added, {len(new_ath)} new players, {len(fixtures)} upcoming fixtures")


# ---------------------------------------------------------------- 2. Rankings
def update_rankings():
    pts = {}
    for code, kind in (('mru', 'm'), ('wru', 'w')):
        j = get(f'https://api.wr-rugby.com/rugby/v1/rankings/{code}')
        if not j or not j.get('entries'):
            log('rankings', code, 'unavailable, keeping previous')
            continue
        rows = []
        for e in j['entries']:
            n = ALIAS.get(e['team']['name'], e['team']['name'])
            rows.append((int(e['pos']), n, round(float(e['pts']), 2)))
        rows.sort()
        if kind == 'm':
            open('rank30.txt', 'w', encoding='utf-8').write('\n'.join(f'{p}|{n}|{v}' for p, n, v in rows[:30]) + '\n')
            pts = {n: v for p, n, v in rows}
        else:
            jsave('rankw.json', {n: [p, v] for p, n, v in rows})
        log('rankings', code, 'updated, effective', (j.get('effective') or {}).get('label'))
    if not pts:
        for l in open('rank30.txt', encoding='utf-8'):
            p, n, v = l.strip().split('|')
            pts[n] = float(v)
    return pts


# ---------------------------------------------------------------- 3. Clubs
CLUB_LEAGUES = {'URC': '270557', 'PREM': '267979', 'T14': '270559', 'SR': '242041', 'ECC': '271937', 'EPC': '272073', 'CC': '270555', 'NPC': '270563'}
SPLIT = {'URC', 'PREM', 'T14', 'ECC', 'EPC'}


def season_of(lg, d):
    y, m = int(d[:4]), int(d[5:7])
    if lg in SPLIT:
        y0 = y if m >= 8 else y - 1
        return f'{y0}–{str(y0 + 1)[2:]}'
    return str(y)


def update_clubs():
    E = jload('club_espn.json', [])
    idx = {r[0]: i for i, r in enumerate(E)}
    start, end = TODAY - dt.timedelta(days=LOOKBACK), TODAY + dt.timedelta(days=AHEAD)
    n_new = 0
    for lg, lid in CLUB_LEAGUES.items():
        for e in scoreboard(lid, start, end):
            eid = 'c' + e['id']
            comp = e['competitions'][0]
            st = (e.get('status') or {}).get('type') or {}
            cs = comp.get('competitors') or []
            if len(cs) != 2:
                continue
            home = next((c for c in cs if c.get('homeAway') == 'home'), cs[0])
            away = next((c for c in cs if c.get('homeAway') == 'away'), cs[1])
            venue = comp.get('venue') or {}
            utc = e['date']
            row = [eid, lg, season_of(lg, utc[:10]), utc[:10], utc[11:16], 'ESPN:' + home['team']['displayName'], '', 'ESPN:' + away['team']['displayName'], '',
                   None, None, [0, 0], None, None, None, 0, venue.get('fullName', ''), ['', ''], '', 0]
            done = st.get('completed') and st.get('state') == 'post'
            if done:
                old = E[idx[eid]] if eid in idx else None
                if old and old[9] is not None:
                    continue
                s = get(f'{SITE}{lid}/summary?event={e["id"]}')
                bx = {t.get('homeAway'): team_stats(t) for t in ((s or {}).get('boxscore') or {}).get('teams') or []}
                h, a = bx.get('home', {}), bx.get('away', {})
                row[9], row[10] = int(float(home.get('score') or 0)), int(float(away.get('score') or 0))
                if 'tries' in h and 'tries' in a:
                    row[12] = [[int(h['tries']), int(a['tries'])]]
                if 'yellowCards' in h:
                    row[13] = [int(h.get('yellowCards', 0)), int(a.get('yellowCards', 0)), int(h.get('redCards', 0)), int(a.get('redCards', 0))]
                gi = (s or {}).get('gameInfo') or {}
                row[15] = gi.get('attendance') or 0
                n_new += 1
            if eid in idx:
                E[idx[eid]] = row
            else:
                idx[eid] = len(E)
                E.append(row)
    jsave('club_espn.json', E)
    log(f'Clubs: {n_new} newly completed matches; {len(E)} ESPN club rows held')


# ---------------------------------------------------------------- 4. Squads and caps (weekly)
def update_wiki():
    from bs4 import BeautifulSoup
    W = jload('wiki_players.json', {'wk': {}, 'caps': []})
    api = 'https://en.wikipedia.org/w/api.php'

    def call(**p):
        p.update(format='json', redirects=1)
        r = S.get(api, params=p, timeout=30)
        return r.json()

    def clean(c):
        x = re.sub(r'\s+', ' ', c.get_text(' ', strip=True))
        return re.sub(r'\(\s+', '(', re.sub(r'\s+\)', ')', x)).strip()

    def tables(html):
        soup = BeautifulSoup(html, 'html.parser')
        out = []
        for t in soup.find_all('table'):
            rows = [[clean(c) for c in tr.find_all(['th', 'td'])] for tr in t.find_all('tr')]
            out.append(rows)
        return out

    teams = [k.split(':', 1) for k in W['wk']] or [['m', n] for n in T10]
    for g, n in teams:
        page = n.replace(' ', '_') + ("_women's" if g == 'w' else '') + '_national_rugby_union_team'
        try:
            secs = call(action='parse', page=page, prop='sections')['parse']['sections']
            sq = []
            for sc in secs:
                if re.search(r'current squad|^squad$', sc['line'], re.I):
                    html = call(action='parse', page=page, prop='text', section=sc['index'])['parse']['text']['*']
                    for rows in tables(html):
                        if rows and any('Caps' in c for c in rows[0]):
                            sq.append([sc['line'], rows])
            if sq:
                W['wk'][f'{g}:{n}'] = {'squad': sq, 'rec': []}
        except Exception as e:
            log('wiki squad failed', n, e)
    try:
        html = call(action='parse', page='List_of_rugby_union_test_caps_leaders', prop='text')['parse']['text']['*']
        for rows in tables(html):
            if rows and rows[0][:3] == ['Rank', 'Caps', 'Player']:
                W['caps'] = rows
                break
    except Exception as e:
        log('wiki caps failed', e)
    jsave('wiki_players.json', W)
    log('Wikipedia squads refreshed for', len(W['wk']), 'teams')


if __name__ == '__main__':
    steps = sys.argv[1:] or ['rankings', 'tests', 'clubs'] + (['wiki'] if TODAY.weekday() == 0 or os.environ.get('FORCE_WIKI') else [])
    pts = {}
    for step in steps:
        try:
            if step == 'rankings':
                pts = update_rankings()
            elif step == 'tests':
                update_tests(pts or update_rankings())
            elif step == 'clubs':
                update_clubs()
            elif step == 'wiki':
                update_wiki()
        except Exception:
            log(f'step {step} failed:\n' + traceback.format_exc())
    print('Finished', f'{dt.datetime.utcnow():%Y-%m-%d %H:%M} UTC')
