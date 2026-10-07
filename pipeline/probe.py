"""Temporary: list ESPN rugby leagues and check sources (run in Actions, prints only)."""
import requests, re, json, datetime as dt
S = requests.Session(); S.headers['User-Agent'] = 'RugbyAnalysis.com data refresh (https://rugbyanalysis.com)'
def g(u, **k):
    try:
        r = S.get(u, timeout=30, **k); return r.json() if r.ok else {'_status': r.status_code}
    except Exception as e: return {'_err': str(e)}
j = g('https://sports.core.api.espn.com/v2/sports/rugby/leagues?limit=1000')
print('core leagues', j.get('count'), list(j)[:6])
ids = [re.search(r'leagues/(\d+)', x['$ref']).group(1) for x in j.get('items', [])]
for i in ids:
    L = g(f'https://sports.core.api.espn.com/v2/sports/rugby/leagues/{i}')
    print('LEAGUE', i, '|', L.get('name'), '|', L.get('abbreviation'), '|', (L.get('season') or {}).get('year'))
for i in ['289234', '289237']:
    for ym in ['202503', '202504', '202509', '202610', '202611']:
        sb = g(f'https://site.api.espn.com/apis/site/v2/sports/rugby/{i}/scoreboard?dates={ym}&limit=1000')
        ev = sb.get('events') or []
        print('SB', i, ym, len(ev), [e['name'] for e in ev][:12])
api = 'https://en.wikipedia.org/w/api.php'
for q in ['2025–26 SVNS', '2026–27 SVNS', '2026 Women\'s Six Nations Championship', '2026 WXV', '2026 Pacific Nations Cup', '2026 Pacific Four Series']:
    r = g(api, params={'action': 'query', 'list': 'search', 'srsearch': q, 'format': 'json', 'srlimit': 5})
    print('WIKI', q, [x['title'] for x in (r.get('query') or {}).get('search', [])])
