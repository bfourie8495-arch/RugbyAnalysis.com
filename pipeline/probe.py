"""Temporary: check data sources from GitHub's servers and save pages for offline parser work."""
import requests, os, json, re
S = requests.Session(); S.headers['User-Agent'] = 'RugbyAnalysis.com data refresh (https://rugbyanalysis.com)'
os.makedirs('_probe', exist_ok=True)
def show(u, **k):
    try:
        r = S.get(u, timeout=30, **k)
        print('URL', r.status_code, len(r.content), u, k.get('params', ''), '|', r.text[:300].replace('\n', ' '))
        return r
    except Exception as e:
        print('URL ERR', u, e)
for u in ['https://site.api.espn.com/apis/site/v2/sports/rugby/270557/scoreboard?dates=202610&limit=1000',
          'https://site.api.espn.com/apis/site/v2/sports/rugby/270557/scoreboard',
          'https://site.web.api.espn.com/apis/site/v2/sports/rugby/270557/scoreboard?dates=202610',
          'https://site.api.espn.com/apis/site/v2/sports/rugby/17567/scoreboard?dates=202611',
          'https://sports.core.api.espn.com/v2/sports/rugby/leagues?limit=5',
          'https://api.wr-rugby.com/rugby/v1/rankings/mru', 'https://cmsapi.pulselive.com/rugby/v3/rankings/mru',
          'https://cmsapi.pulselive.com/rugby/rankings/mru', 'https://api.world.rugby/rugby/v1/rankings/mru',
          'https://www.world.rugby/tournaments/rankings/mru', 'https://league-one.jp/', 'https://league-one.jp/match/']:
    show(u)
api = 'https://en.wikipedia.org/w/api.php'
pages = ['2026–27 United Rugby Championship', '2025–26 United Rugby Championship', '2026–27 Premiership Rugby', '2025–26 Premiership Rugby',
         '2026–27 Top 14 season', '2025–26 Top 14 season', '2026 Super Rugby Pacific season', '2026–27 European Rugby Champions Cup',
         '2026–27 EPCR Challenge Cup', '2026 Currie Cup Premier Division', '2026 Bunnings NPC', '2026 National Provincial Championship',
         '2026–27 Japan Rugby League One – Division 1', '2025–26 Japan Rugby League One – Division 1',
         '2026 Six Nations Championship', '2026 Nations Championship', '2026 mid-year rugby union internationals',
         '2026 end-of-year rugby union internationals', '2026 Bledisloe Cup', '2026 Rugby Championship',
         'World Rugby Rankings', "World Rugby Women's Rankings", '2026–27 SVNS', '2026 Spain Sevens', '2026 France Sevens', '2026 Singapore Sevens']
for p in pages:
    r = S.get(api, params={'action': 'parse', 'page': p, 'prop': 'text|sections', 'format': 'json', 'redirects': 1}, timeout=60).json()
    if 'parse' not in r:
        s = S.get(api, params={'action': 'query', 'list': 'search', 'srsearch': p, 'format': 'json', 'srlimit': 6}, timeout=30).json()
        print('MISSING', p, '| search:', [x['title'] for x in s.get('query', {}).get('search', [])]); continue
    h = r['parse']['text']['*']
    open('_probe/' + p.replace('/', '_') + '.html', 'w').write(h)
    print('SAVED', p, '->', r['parse']['title'], len(h), 'vevents', h.count('vevent'), [s['line'] for s in r['parse']['sections']][:30])
r = S.get('https://ja.wikipedia.org/w/api.php', params={'action': 'query', 'list': 'search', 'srsearch': 'リーグワン 2026-27 ディビジョン1', 'format': 'json'}, timeout=30).json()
print('JAWIKI', [x['title'] for x in r.get('query', {}).get('search', [])][:8])
