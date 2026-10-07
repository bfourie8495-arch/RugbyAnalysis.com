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
        fixtures += [o for o in old.values() if (o.get('manual') or o.get('src') == 'wiki') and (o.get('d') or o['ko'][:10]) >= TODAY.isoformat()]
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


# ---------------------------------------------------------------- 5. Competitions ESPN does not carry (Wikipedia)
import wiki_feed

# Competition pages, by year; a page that does not exist yet is skipped
WIKI_TESTS = {'m': ['{y} World Rugby Pacific Nations Cup', '{y} Rugby Europe Championship'],
              'w': ["{y} Women's Six Nations Championship", '{y} WXV Global Series', '{y} WXV Global Series Challenger',
                    '{y} Pacific Four Series', "{y} Rugby Europe Women's Championship", "{y} Women's Rugby World Cup"]}
TZ_OFF = {'GMT': 0, 'UTC': 0, 'WET': 0, 'BST': 1, 'IST': 1, 'WEST': 1, 'CET': 1, 'CEST': 2, 'EET': 2, 'EEST': 3, 'SAST': 2, 'CAT': 2, 'EAT': 3,
          'GST': 4, 'HKT': 8, 'SGT': 8, 'AWST': 8, 'JST': 9, 'KST': 9, 'AEST': 10, 'AEDT': 11, 'ACST': 9.5, 'NZST': 12, 'NZDT': 13, 'FJT': 12,
          'TOT': 13, 'WST': 13, 'EST': -5, 'EDT': -4, 'CST': -6, 'CDT': -5, 'MST': -7, 'MDT': -6, 'PST': -8, 'PDT': -7, 'ART': -3, 'BRT': -3, 'UYT': -3}


def _ko(m):
    """Kick-off in UTC from a match box's local time and zone ('13:25 CET'); None when the zone is unknown."""
    t = re.match(r'(\d{1,2}):(\d{2})\s*([A-Z]+)?([+\-]\d+)?', m['time'] or '')
    if not t or m['nd'] or (t.group(3) not in TZ_OFF and not t.group(4)):
        return None
    off = TZ_OFF.get(t.group(3), 0) + (int(t.group(4)) if t.group(4) else 0)
    k = dt.datetime.fromisoformat(m['date']) + dt.timedelta(hours=int(t.group(1)), minutes=int(t.group(2))) - dt.timedelta(hours=off)
    return k.strftime('%Y-%m-%dT%H:%M:00Z')


def _nation(title):
    n = re.sub(r"\s+(women's\s+)?national\s+(rugby\s+union\s+)?(team|XV)$", '', title, flags=re.I).strip()
    n = ALIAS.get(n, n)
    return n if n in NAMES else None


def update_wiki_tests():
    """Results (with scorers) and upcoming fixtures for the Test competitions above."""
    men = pd.read_csv(MEN_CSV, sep=';', dtype=str, keep_default_na=False)
    wom = pd.read_csv(WOMEN_CSV, sep=';', dtype=str, keep_default_na=False)
    rank = {'m': {l.split('|')[1]: float(l.split('|')[2]) for l in open('rank30.txt', encoding='utf-8') if l.strip()},
            'w': {n: v[1] for n, v in jload('rankw.json', {}).items()}}
    # where each nation plays its home Tests, to tell home games from neutral ones
    home_city = {}
    for df in (men, wom):
        for r in df[(df.country != '') & (df.neutral == 'FALSE')].itertuples():
            home_city.setdefault(r.city.lower(), r.country)
    years = sorted({TODAY.year, (TODAY - dt.timedelta(days=LOOKBACK)).year})
    fixtures, added, filled = [], {'m': 0, 'w': 0}, 0
    for g, pages in WIKI_TESTS.items():
        for y in years:
            for page in pages:
                page = page.format(y=y)
                html = wiki_feed.fetch(S, page)
                if not html:
                    continue
                ms = wiki_feed.matches(html)
                log(f'Wikipedia: {page}: {len(ms)} matches, {sum(m["hs"] is not None for m in ms)} played')
                for m in ms:
                    h, a = _nation(m['home']), _nation(m['away'])
                    if not h or not a:
                        continue
                    if m['hs'] is None:
                        if TODAY.isoformat() <= m['date'] <= (TODAY + dt.timedelta(days=AHEAD)).isoformat():
                            rp = rank[g]
                            if h in rp or a in rp:
                                rh, ra = rp.get(h, 50), rp.get(a, 50)
                                p = 1 / (1 + 10 ** (-(rh + 3 - ra) / 10 * 0.6))
                                fixtures.append({'ko': _ko(m), 'd': m['date'], 'h': h, 'a': a, 'c': page[5:] if page[:4].isdigit() else page,
                                                 'v': ', '.join(x for x in [m['stadium'], m['city']] if x) or 'Venue TBC', 'p': round(p, 2),
                                                 **({'g': 'w'} if g == 'w' else {}), 'src': 'wiki'})
                        continue
                    df = wom if g == 'w' else men
                    d = m['date'].replace('-', '/')
                    sc = lambda side, k: str(m[side][k])
                    detail = dict(home_tries=sc('h', 'tries'), away_tries=sc('a', 'tries'), home_cons=sc('h', 'cons'), away_cons=sc('a', 'cons'),
                                  home_cons_att=sc('h', 'cons_att'), away_cons_att=sc('a', 'cons_att'), home_pens=sc('h', 'pens'), away_pens=sc('a', 'pens'),
                                  home_pens_att=sc('h', 'pens_att'), away_pens_att=sc('a', 'pens_att'), home_drops=sc('h', 'drops'), away_drops=sc('a', 'drops'),
                                  home_try_scorers='; '.join(m['h']['scorers']), away_try_scorers='; '.join(m['a']['scorers']))
                    same = (df.date == d) & (df.home_team == h) & (df.away_team == a)
                    if same.any():
                        # a result we already hold (often from ESPN, without scorers): fill in what is missing
                        k = df.index[same][0]
                        if not df.at[k, 'home_try_scorers'] and not df.at[k, 'away_try_scorers'] and (detail['home_try_scorers'] or detail['away_try_scorers']):
                            for c, v in detail.items():
                                if not df.at[k, c]:
                                    df.at[k, c] = v
                            filled += 1
                        continue
                    d0 = dt.date.fromisoformat(m['date'])
                    near = df[df.date.isin([(d0 + dt.timedelta(days=i)).strftime('%Y/%m/%d') for i in (-1, 0, 1)])]
                    if (((near.home_team == h) & (near.away_team == a)) | ((near.home_team == a) & (near.away_team == h))).any():
                        continue
                    country = home_city.get(m['city'].lower(), '')
                    row = {c: '' for c in df.columns}
                    row.update(date=d, home_team=h, away_team=a, home_score=str(m['hs']), away_score=str(m['as']), competition=page,
                               stadium=m['stadium'], city=m['city'], country=country, neutral='TRUE' if country and country != h else 'FALSE',
                               world_cup='TRUE' if 'World Cup' in page else 'FALSE', referee=m['referee'],
                               attendance=str(m['attendance']) if m['attendance'] else '', **detail)
                    df.loc[len(df)] = row
                    added[g] += 1
                    log('new Test (Wikipedia)', d, h, m['hs'], '-', m['as'], a)
    for df, f in ((men, MEN_CSV), (wom, WOMEN_CSV)):
        df.to_csv(f, sep=';', index=False)
    # fixtures: ESPN's list stays first choice; Wikipedia fills the gaps
    cur = [f for f in jload('fixtures.json', []) if f.get('src') != 'wiki']
    have = {(f.get('d') or f['ko'][:10], frozenset((f['h'], f['a']))) for f in cur}
    for f in fixtures:
        d0 = dt.date.fromisoformat(f['d'])
        if not any((str(d0 + dt.timedelta(days=i)), frozenset((f['h'], f['a']))) in have for i in (-1, 0, 1)):
            cur.append(f)
            have.add((f['d'], frozenset((f['h'], f['a']))))
    cur.sort(key=lambda f: f.get('d') or f['ko'][:10])
    jsave('fixtures.json', cur)
    log(f"Wikipedia Tests: {added['m']} men's and {added['w']} women's results added, {filled} filled in, {len(fixtures)} upcoming")


def _season(d=None):
    d = d or TODAY
    y = d.year if d.month >= 7 else d.year - 1
    return f'{y}–{str(y + 1)[2:]}'


def _club_rows(lg, season, ms):
    rows = []
    for m in ms:
        if m['tbd']:
            continue
        played = m['hs'] is not None
        sc = [[m['h'][k], m['a'][k]] for k in ('tries', 'cons', 'cons_att', 'pens', 'pens_att', 'drops')] if played else 0
        r = [lg, season, m['date'], m['time'], m['home'], m['home_name'], m['away'], m['away_name'], m['hs'], m['as'],
             m['bp'] if played else [0, 0], sc, 0, m['referee'], m['attendance'], m['stadium'],
             ['; '.join(m['h']['scorers']), '; '.join(m['a']['scorers'])], m['stage']]
        if m['nd']:
            r.append(1)
        rows.append(r)
    return rows


def update_pwr():
    """Premiership Women's Rugby: the current season's results, fixtures and table, replaced wholesale from its page."""
    se = _season()
    html = wiki_feed.fetch(S, f"{se} Premiership Women's Rugby")
    if not html:
        log('PWR: no page for', se); return
    ms = wiki_feed.matches(html)
    P, cup = jload('pwr_raw.json', {'rows': [], 'tabs': {}}), jload('pwr_cup.json', [])
    old = [r for r in P['rows'] if r[1] == se]
    if len(ms) < max(10, len(old) // 2):
        log(f'PWR: only {len(ms)} matches on the {se} page (held {len(old)}), keeping what we have'); return
    keys = {(r[2], r[4], r[6]) for r in old}
    cup = [c for c in cup if tuple(c[:3]) not in keys]
    cup += [[m['date'], m['home'], m['away'], m['section']] for m in ms if not m['tbd'] and m['section'] not in ('Regular season', 'Play-offs')]
    P['rows'] = [r for r in P['rows'] if r[1] != se] + _club_rows('PWR', se, ms)
    T = wiki_feed.tables(html)
    if T and len(T[0]) >= 6:
        P['tabs'][se] = T[0]
    jsave('pwr_raw.json', P)
    jsave('pwr_cup.json', cup)
    log(f'PWR {se}: {len(ms)} matches ({sum(m["hs"] is not None for m in ms)} played), table {"updated" if T else "not found"}')


def update_jl1():
    """Japan Rugby League One (Division 1), from its season page when it carries match boxes."""
    se = _season()
    html = wiki_feed.fetch(S, f'{se} Japan Rugby League One – Division 1')
    ms = wiki_feed.matches(html) if html else []
    X = jload('xcomp_raw.json', {'rows': [], 'tabs': {}})
    old = [r for r in X['rows'] if r[0] == 'JL1' and r[1] == se]
    if len(ms) < max(10, len(old) // 2):
        log(f'League One {se}: {len(ms)} match boxes on Wikipedia (held {len(old)}), keeping what we have'); return
    X['rows'] = [r for r in X['rows'] if not (r[0] == 'JL1' and r[1] == se)] + _club_rows('JL1', se, ms)
    T = wiki_feed.tables(html)
    if T and len(T[0]) >= 6:
        X['tabs']['JL1' + se] = T[0]
    jsave('xcomp_raw.json', X)
    log(f'League One {se}: {len(ms)} matches ({sum(m["hs"] is not None for m in ms)} played)')


def update_sevens():
    """SVNS: each finished leg's champion and runner-up, and the series standings, for this and last season."""
    D = jload('sevens_data.json', None)
    if not D:
        return
    seasons = sorted({_season(), _season(TODAY - dt.timedelta(days=180))})
    from bs4 import BeautifulSoup
    new = 0
    for se in seasons:
        html = wiki_feed.fetch(S, f'{se} SVNS')
        if not html:
            continue
        soup = BeautifulSoup(html, 'html.parser')
        legs = None
        for t in soup.select('table.wikitable'):
            hdr = [wiki_feed._txt(c) for c in t.find('tr').find_all(['th', 'td'])]
            if 'Leg' in hdr and "Men's Winner" in hdr:
                legs = (hdr, t.find_all('tr')[1:])
                break
        if not legs:
            continue
        hdr, trs = legs
        for tr in trs:
            cells = tr.find_all(['th', 'td'])
            if len(cells) != len(hdr):
                continue
            c = dict(zip(hdr, cells))
            a = c['Leg'].find('a')
            title = a.get('title') if a else ''
            ym = re.search(r'([A-Z][a-z]{2})[a-z]*\s+(\d{4})\s*$', wiki_feed._txt(c['Dates']))
            if not title or not ym:
                continue
            ym = f"{ym.group(2)}-{['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'].index(ym.group(1)) + 1:02d}"
            for g, col, head in (('m', "Men's Winner", "Men"), ('w', "Women's Winner", "Women")):
                ch = wiki_feed._txt(c.get(col))
                if not ch or ch.upper() in ('TBA', 'TBD'):
                    continue
                ev = next((e for e in D['events'] if e['g'] == g and e['title'] == title), None)
                if ev and ev.get('ru'):
                    continue
                th = wiki_feed.fetch(S, title)
                pl = wiki_feed.placings(th, head) if th else None
                ru = pl[1] if pl and pl[0] == ch else ''
                if ev:
                    ev['ru'] = ev['ru'] or ru
                else:
                    D['events'].append({'g': g, 'season': se, 'title': title, 'host': wiki_feed._txt(c['Leg']), 'ym': ym, 'ch': ch, 'ru': ru, 's1': None, 's2': None})
                    new += 1
                    log('Sevens: new leg', g, title, ch, ru)
        # series standings: the first two points tables are the men's and the women's
        pts = [t for t in soup.select('table.wikitable') if wiki_feed._txt(t.find('tr')).startswith('Pos.')][:2]
        for g, t in zip(('m', 'w'), pts):
            hdr = [wiki_feed._txt(x) for x in t.find('tr').find_all(['th', 'td'])]
            rows = [[wiki_feed._txt(x) for x in tr.find_all(['th', 'td'])] for tr in t.find_all('tr')[1:]]
            rows = [r for r in rows if len(r) == len(hdr)]
            if len(rows) < 6 or 'Points total' not in hdr:
                continue
            done = [i for i, h in enumerate(hdr[2:hdr.index('Points total')], 2) if any(r[i] not in ('', '–', '-') for r in rows)]
            if not done:
                continue
            ent = {'season': se, 'codes': [r[1] for r in rows[:6]], 'pts': int(re.sub(r'\D', '', rows[0][hdr.index('Points total')]) or 0), 'rds': len(done)}
            T = D['top'][g]
            k = next((i for i, x in enumerate(T) if x['season'] == se), None)
            if k is None:
                T.append(ent)
            else:
                T[k] = ent
    D['events'].sort(key=lambda e: (e['g'], e['ym']))
    jsave('sevens_data.json', D)
    log(f'Sevens: {new} new legs')


if __name__ == '__main__':
    steps = sys.argv[1:] or ['rankings', 'tests', 'clubs', 'wikitests', 'pwr', 'jl1', 'sevens'] + (['wiki'] if TODAY.weekday() == 0 or os.environ.get('FORCE_WIKI') else [])
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
            elif step == 'wikitests':
                update_wiki_tests()
            elif step == 'pwr':
                update_pwr()
            elif step == 'jl1':
                update_jl1()
            elif step == 'sevens':
                update_sevens()
        except Exception:
            log(f'step {step} failed:\n' + traceback.format_exc())
    print('Finished', f'{dt.datetime.utcnow():%Y-%m-%d %H:%M} UTC')
