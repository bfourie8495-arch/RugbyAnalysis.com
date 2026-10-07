"""Temporary: find the League One and Rugby Europe pages."""
import requests, os
S = requests.Session(); S.headers['User-Agent'] = 'RugbyAnalysis.com data refresh (https://rugbyanalysis.com)'
api = 'https://en.wikipedia.org/w/api.php'
os.makedirs('_probe', exist_ok=True)
for q in ['Japan Rugby League One 2025–26 season', 'League One Division 1 2026–27', 'Rugby Europe Championship 2026', "Rugby Europe Women's Championship 2026", "WXV Global Series Challenger 2026"]:
    r = S.get(api, params={'action': 'query', 'list': 'search', 'srsearch': q, 'format': 'json', 'srlimit': 8}, timeout=30).json()
    print('WIKI', q, [x['title'] for x in r['query']['search']])
for p in ['2025–26 Japan Rugby League One season', '2026–27 Japan Rugby League One season', '2025–26 Japan Rugby League One – Division One', '2026 Rugby Europe Championship', "2026 Rugby Europe Women's Championship", '2026 WXV Global Series Challenger']:
    r = S.get(api, params={'action': 'parse', 'page': p, 'prop': 'text', 'format': 'json', 'redirects': 1}, timeout=60).json()
    if 'parse' in r:
        open('_probe/' + p + '.html', 'w').write(r['parse']['text']['*']); print('SAVED', p, r['parse']['title'])
    else:
        print('MISSING', p)
