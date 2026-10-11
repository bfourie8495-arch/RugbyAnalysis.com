"""Temporary: third round, saved to files."""
import requests, os, json, re
S = requests.Session(); S.headers['User-Agent'] = 'RugbyAnalysis.com data refresh (https://rugbyanalysis.com)'
os.makedirs('_probe', exist_ok=True)
out = []
def save(name, u):
    try:
        r = S.get(u, timeout=30); open('_probe/' + name, 'w').write(r.text); out.append(f'{r.status_code} {len(r.content)} {u}'); return r
    except Exception as e:
        out.append(f'ERR {u} {e}')
W = 'https://site.web.api.espn.com/apis/site/v2/sports/rugby/'
sb = save('espn_urc_202610.json', W + '270557/scoreboard?dates=202610&limit=1000')
ev = sb.json().get('events') or []
done = [e for e in ev if (e.get('status') or {}).get('type', {}).get('completed')]
out.append(f'URC Oct events {len(ev)} done {len(done)}')
if done:
    save('espn_summary.json', W + f'270557/summary?event={done[0]["id"]}')
for lg in ['17567', '289234', '180659', '244293', '289237', '267979', '270559', '242041', '271937', '272073', '270555', '270563']:
    try:
        r = S.get(W + f'{lg}/scoreboard?dates=2026&limit=1000', timeout=30)
        e = r.json().get('events') or [] if r.ok else []
        out.append(f'LG {lg} {r.status_code} {(r.json().get("leagues") or [{}])[0].get("name") if r.ok else ""} {len(e)} {max((x["date"][:10] for x in e), default="")}')
    except Exception as ex:
        out.append(f'LG {lg} ERR {ex}')
save('espn_core_athlete.json', 'https://sports.core.api.espn.com/v2/sports/rugby/athletes/266583')
save('wr_mru.json', 'https://api.world.rugby/rugby/v3/rankings/mru')
save('wr_wru.json', 'https://api.world.rugby/rugby/v3/rankings/wru')
save('l1_schedule.html', 'https://league-one.jp/schedule/')
save('l1_en.html', 'https://league-one.jp/en/')
save('l1_standings.html', 'https://league-one.jp/standings/')
save('l1_match_31037.html', 'https://league-one.jp/match/31037')
open('_probe/log.txt', 'w').write('\n'.join(out))
print('\n'.join(out))
