"""Temporary: second round of source checks from GitHub's servers."""
import requests, os, json, re
S = requests.Session(); S.headers['User-Agent'] = 'RugbyAnalysis.com data refresh (https://rugbyanalysis.com)'
os.makedirs('_probe', exist_ok=True)
def show(u, n=300, **k):
    try:
        r = S.get(u, timeout=30, **k)
        print('URL', r.status_code, len(r.content), u, '|', r.text[:n].replace('\n', ' '))
        return r
    except Exception as e:
        print('URL ERR', u, e)
W = 'https://site.web.api.espn.com/apis/site/v2/sports/rugby/'
sb = show(W + '270557/scoreboard?dates=202610&limit=1000', 100)
ev = (sb.json().get('events') or []) if sb is not None and sb.ok else []
print('events', len(ev), [(e['id'], e['name'], (e.get('status') or {}).get('type', {}).get('completed')) for e in ev][:5])
done = [e for e in ev if (e.get('status') or {}).get('type', {}).get('completed')]
if done:
    r = show(W + f'270557/summary?event={done[0]["id"]}', 200)
    if r is not None and r.ok:
        j = r.json(); print('summary keys', list(j), 'rosters', len(j.get('rosters') or []), 'box teams', len((j.get('boxscore') or {}).get('teams') or []))
for lg in ['17567', '289234', '180659', '244293', '164205', '289237', '267979', '270559', '242041', '271937', '272073', '270555', '270563']:
    r = show(W + f'{lg}/scoreboard?dates=2026&limit=1000', 0)
    if r is not None and r.ok:
        e = r.json().get('events') or []; print('  LG', lg, (r.json().get('leagues') or [{}])[0].get('name'), len(e), sorted(x['date'][:10] for x in e)[-1:] if e else '')
show('https://sports.core.api.espn.com/v2/sports/athletes/1', 0)
j = S.get('https://sports.core.api.espn.com/v2/sports/rugby/leagues?limit=100', timeout=30).json()
for it in j.get('items', []):
    L = S.get(it['$ref'].replace('http://', 'https://'), timeout=30).json()
    print('LEAGUE', L.get('id'), '|', L.get('name'), '|', (L.get('season') or {}).get('year'))
r = show('https://www.world.rugby/tournaments/rankings/mru', 0)
if r is not None:
    print('WR api refs', sorted(set(re.findall(r'https?://[a-zA-Z0-9.\-]+(?:/[^"\'\s<>]*)?', r.text)))[:80])
    print('WR data hints', re.findall(r'data-[a-z\-]*(?:api|url|endpoint)[a-z\-]*="[^"]+"', r.text)[:20])
for u in ['https://api.wr-rugby.com/rugby/v1/rankings/mru', 'https://api.world.rugby/rugby/v1/rankings/mru', 'https://api.world.rugby/rankings/mru',
          'https://api.world.rugby/rugby/v3/rankings/mru', 'https://cmsapi.pulselive.com/rugby/v1/rankings/mru']:
    show(u, 200)
r = show('https://league-one.jp/', 0)
if r is not None:
    print('L1 links', sorted(set(re.findall(r'href="([^"]+)"', r.text)))[:120])
for u in ['https://league-one.jp/schedule/', 'https://league-one.jp/match/schedule/', 'https://league-one.jp/en/', 'https://league-one.jp/standings/']:
    r = show(u, 0)
api = 'https://en.wikipedia.org/w/api.php'
for p in ["World Rugby Women's World Rankings"]:
    r = S.get(api, params={'action': 'parse', 'page': p, 'prop': 'text', 'format': 'json', 'redirects': 1}, timeout=60).json()
    if 'parse' in r:
        open('_probe/' + p + '.html', 'w').write(r['parse']['text']['*']); print('SAVED', p)
