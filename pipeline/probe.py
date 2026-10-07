"""Temporary: save Wikipedia page HTML so the parsers can be written offline."""
import requests, os, json
S = requests.Session(); S.headers['User-Agent'] = 'RugbyAnalysis.com data refresh (https://rugbyanalysis.com)'
api = 'https://en.wikipedia.org/w/api.php'
os.makedirs('_probe', exist_ok=True)
for q in ['2026–27 Premiership Women\'s Rugby', '2025–26 Premiership Women\'s Rugby', '2026–27 Japan Rugby League One', '2025–26 Japan Rugby League One']:
    r = S.get(api, params={'action': 'query', 'list': 'search', 'srsearch': q, 'format': 'json', 'srlimit': 5}, timeout=30).json()
    print('WIKI', q, [x['title'] for x in r['query']['search']])
pages = ["2026 Women's Six Nations Championship", '2026 WXV Global Series', '2026 Pacific Four Series', '2026 World Rugby Pacific Nations Cup',
         '2026–27 SVNS', '2025–26 SVNS', "2026–27 Premiership Women's Rugby", "2025–26 Premiership Women's Rugby", '2025–26 Japan Rugby League One', '2026–27 Japan Rugby League One',
         '2026 Hong Kong Sevens', "2026 Women's Rugby World Cup"]
for p in pages:
    r = S.get(api, params={'action': 'parse', 'page': p, 'prop': 'text|sections', 'format': 'json', 'redirects': 1}, timeout=60).json()
    if 'parse' not in r:
        print('MISSING', p, r.get('error', {}).get('code')); continue
    open('_probe/' + p.replace('/', '_') + '.html', 'w').write(r['parse']['text']['*'])
    print('SAVED', p, len(r['parse']['text']['*']), [s['line'] for s in r['parse']['sections']][:25])
