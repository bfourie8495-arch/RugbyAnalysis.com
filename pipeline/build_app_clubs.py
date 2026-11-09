"""The app's club feed, site/app/clubs.json, from the same data as the website's clubs page (clubs_data.json):
for each of the ten competitions its current season's table, latest results and next fixtures, and for each
club its form, latest results and next games. Kick-off times become UTC (the club data keeps them in the home
club's time zone), so the app shows them in the phone's own time.

Run by build_all.py after build_clubs.py.
"""
import collections, datetime as dt, json, os, re
from zoneinfo import ZoneInfo

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, '..', 'site', 'app', 'clubs.json')
TODAY = dt.date.today().isoformat()
RESULTS, FIXTURES, CLUB_GAMES = 16, 16, 6


def league_meta():
    """Names, colours and 'how it works' text from the website's clubs page, so both say the same."""
    src = open(os.path.join(HERE, 'clubs_template.html'), encoding='utf-8').read()
    out = {}
    for m in re.finditer(r'LG\("(\w+)","([^"]+)","([^"]+)","([^"]+)","(#\w+)","(#\w+)","(#\w+)","([^"]*)",(\d+),\{(.*?)\}\)', src):
        lid, name, short, code, bg, accent, light, where, playoff, extra = m.groups()
        how = re.search(r'how:"((?:[^"\\]|\\.)*)"', extra)
        out[code] = {'id': lid, 'name': name, 'short': short, 'bg': bg, 'accent': accent, 'light': light, 'where': where,
                     'playoff': int(playoff), 'g': 'w' if 'g:"w"' in extra else 'm', 'cup': 'cup:true' in extra,
                     'how': how.group(1).replace('\\"', '"') if how else ''}
    return out


def utc(date, time, tz):
    if not time: return None
    t = dt.datetime.fromisoformat('%sT%s:00' % (date, time)).replace(tzinfo=ZoneInfo(tz or 'UTC'))
    return t.astimezone(dt.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')


def main():
    D = json.load(open(os.path.join(HERE, 'clubs_data.json'), encoding='utf-8'))
    C, S, L = D['clubs'], D['seasons'], D['leagues']
    meta = league_meta()
    venues = D['venues']
    rows = [r for r in D['rows'] if r[2]]
    rows.sort(key=lambda r: (r[2], r[3] or ''))

    def game(r):
        g = {'d': r[2], 'h': C[r[4]]['id'], 'a': C[r[5]]['id']}
        if r[6] is not None: g.update(hs=r[6], **{'as': r[7]})
        ko = utc(r[2], r[3], C[r[4]]['tz'])
        if ko and r[6] is None: g['ko'] = ko
        if r[13] >= 0 and venues[r[13]].strip().upper() not in ('TBC', 'TBA', ''): g['v'] = venues[r[13]]
        if r[17]: g['r'] = r[17]
        return g

    leagues, used = [], set()
    for li, code in enumerate(L):
        mine = [r for r in rows if r[0] == li]
        if not mine: continue
        cur = max(r[1] for r in mine)
        # A season that hasn't started yet still shows last season's table until it has one of its own.
        played_now = [r for r in mine if r[1] == cur and r[6] is not None]
        tab_season = cur if '%d-%d' % (li, cur) in D['tables'] else max((int(k.split('-')[1]) for k in D['tables'] if k.startswith('%d-' % li)), default=None)
        table = D['tables'].get('%d-%d' % (li, tab_season)) if tab_season is not None else None
        res = [r for r in mine if r[6] is not None][-RESULTS:][::-1]
        fx = [r for r in mine if r[6] is None and r[2] >= TODAY][:FIXTURES]
        m = meta.get(code, {})
        lg = {'id': m.get('id', code.lower()), 'code': code, 'name': m.get('name', code), 'short': m.get('short', code),
              'g': m.get('g', 'm'), 'colours': [m.get('bg'), m.get('accent'), m.get('light')], 'where': m.get('where', ''),
              'playoff': m.get('playoff', 0), 'cup': m.get('cup', False), 'how': m.get('how', ''),
              'season': S[cur], 'started': bool(played_now),
              'results': [game(r) for r in res], 'fixtures': [game(r) for r in fx]}
        if table:
            # [club, won, drawn, lost, for, against, tries for, tries against, try bonus, losing bonus, points]
            lg['tableSeason'] = S[tab_season]
            lg['table'] = [[C[t[0]]['id'], t[1] + t[2] + t[3], t[1], t[2], t[3], t[4], t[5], t[8] + t[9], t[10]] for t in table]
            used.update(C[t[0]]['id'] for t in table)
        used.update(g['h'] for g in lg['results'] + lg['fixtures'])
        used.update(g['a'] for g in lg['results'] + lg['fixtures'])
        leagues.append(lg)

    # Each club: its details, form (last five, oldest first), latest results and next games in any competition.
    by_club = collections.defaultdict(list)
    for r in rows:
        by_club[r[4]].append(r); by_club[r[5]].append(r)
    clubs = {}
    for i, c in enumerate(C):
        if c['id'] not in used: continue
        mine = by_club[i]
        done = [r for r in mine if r[6] is not None]
        def res(r):
            my, op = (r[6], r[7]) if r[4] == i else (r[7], r[6])
            return 'W' if my > op else 'L' if my < op else 'D'
        clubs[c['id']] = {
            'name': c['name'], 'code': c['code'], 'lg': c['lg'], 'country': c['country'], 'city': c['city'],
            'colours': [c['p'], c['onp'], c['al'], c['ad']],
            'form': ''.join(res(r) for r in done[-5:]),
            'results': [dict(game(r), c=L[r[0]]) for r in done[-CLUB_GAMES:][::-1]],
            'fixtures': [dict(game(r), c=L[r[0]]) for r in mine if r[6] is None and r[2] >= TODAY][:CLUB_GAMES],
        }
    out = {'asOf': TODAY, 'leagues': leagues, 'clubs': clubs}
    json.dump(out, open(OUT, 'w', encoding='utf-8'), ensure_ascii=False, separators=(',', ':'))
    print('clubs.json: %d competitions, %d clubs, %d KB' % (len(leagues), len(clubs), os.path.getsize(OUT) // 1024))


if __name__ == '__main__':
    main()
