"""Temporary: League One past-season pages and an ESPN athlete lookup."""
import requests, os, json, re
S = requests.Session(); S.headers['User-Agent'] = 'RugbyAnalysis.com data refresh (https://rugbyanalysis.com)'
os.makedirs('_probe', exist_ok=True)
out = []
def save(name, u, **k):
    try:
        r = S.get(u, timeout=30, **k); open('_probe/' + name, 'w').write(r.text); out.append(f'{r.status_code} {len(r.content)} {r.url} {r.text.count("c-schedule")}'); return r
    except Exception as e:
        out.append(f'ERR {u} {e}')
save('l1_s2025_a.html', 'https://league-one.jp/schedule/?season=2025')
save('l1_s2025_b.html', 'https://league-one.jp/schedule/2025/')
save('l1_s2025_c.html', 'https://league-one.jp/schedule/?year=2025')
save('l1_en_schedule.html', 'https://league-one.jp/en/schedule/')
sm = json.load(open('_probe/espn_summary.json'))
aid = next(x['athlete']['id'] for r in sm.get('rosters') or [] for x in r.get('roster') or [] if (x.get('athlete') or {}).get('id'))
out.append(f'athlete {aid}')
for u in [f'https://sports.core.api.espn.com/v2/sports/rugby/athletes/{aid}', f'https://sports.core.api.espn.com/v2/sports/rugby/leagues/270557/athletes/{aid}',
          f'https://site.web.api.espn.com/apis/common/v3/sports/rugby/athletes/{aid}', f'https://site.web.api.espn.com/apis/common/v3/sports/rugby/270557/athletes/{aid}']:
    try:
        r = S.get(u, timeout=30); out.append(f'{r.status_code} {u} {r.text[:250]}')
    except Exception as e:
        out.append(f'ERR {u} {e}')
open('_probe/log.txt', 'w').write('\n'.join(out)); print('\n'.join(out))
