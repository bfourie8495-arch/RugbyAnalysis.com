"""Build the app's matchday feed: World Rugby rankings, upcoming Tests with the model's pick, the latest results,
each nation's recent form, and each nation's colours, short code and flag (as an ISO code the app turns into a
flag emoji). Men's and women's internationals. Writes ../site/app/matchday.json, served at
https://rugbyanalysis.com/app/matchday.json for the RugbyAnalysis app.

Runs from build_all.py after update.py. If anything goes wrong, the previous file is kept and the run shows a
yellow warning instead of stopping the rest of the site build."""
import collections, json, os, re, datetime
import pandas as pd

import insights as I

OUT = os.path.join('..', 'site', 'app', 'matchday.json')
TODAY = datetime.date.today().isoformat()
ALIAS = {'United States of America': 'United States', 'USA': 'United States', 'Hong Kong China': 'Hong Kong',
         'Czechia': 'Czech Republic'}
RESULTS = 40          # latest results kept for each of men and women
FORM = 5              # results in a nation's form guide

# Top-10 nations' colours and nicknames, as on the website (template.html); others come from others.json.
T10 = {'Argentina': ('Los Pumas', '#74ACDF', '#0A2240'), 'Australia': ('The Wallabies', '#FFB81C', '#073B22'),
       'England': ('The Red Rose', '#F4F4F2', '#0B1E3F'), 'France': ('Les Bleus', '#0A2A66', '#FFFFFF'),
       'Ireland': ('The Shamrock', '#00703C', '#FFFFFF'), 'Italy': ('Gli Azzurri', '#0B5CAD', '#FFFFFF'),
       'New Zealand': ('The All Blacks', '#000000', '#FFFFFF'), 'Scotland': ('The Thistle', '#0B2341', '#FFFFFF'),
       'South Africa': ('The Springboks', '#006A4E', '#FFFFFF'), 'Wales': ('Y Dreigiau Cochion', '#C8102E', '#FFFFFF')}
CODE = {'New Zealand': 'NZL', 'South Africa': 'RSA', 'Ireland': 'IRE', 'France': 'FRA', 'England': 'ENG', 'Australia': 'AUS',
        'Scotland': 'SCO', 'Argentina': 'ARG', 'Fiji': 'FIJ', 'Wales': 'WAL', 'Italy': 'ITA', 'Japan': 'JPN', 'Georgia': 'GEO',
        'United States': 'USA', 'Portugal': 'POR', 'Chile': 'CHI', 'Spain': 'ESP', 'Uruguay': 'URU', 'Tonga': 'TGA',
        'Samoa': 'SAM', 'Romania': 'ROU', 'Canada': 'CAN', 'Hong Kong': 'HKG', 'Namibia': 'NAM', 'Belgium': 'BEL',
        'Netherlands': 'NED', 'Zimbabwe': 'ZIM', 'Kazakhstan': 'KAZ', 'Russia': 'RUS', 'Germany': 'GER', 'Switzerland': 'SUI',
        'Czech Republic': 'CZE', 'Poland': 'POL', 'Kenya': 'KEN', 'South Korea': 'KOR', 'China': 'CHN', 'Brazil': 'BRA',
        'Mexico': 'MEX', 'Paraguay': 'PAR', 'Colombia': 'COL', 'Sweden': 'SWE', 'Uganda': 'UGA', 'Philippines': 'PHI',
        'Sri Lanka': 'SRI', 'Malaysia': 'MAS', 'Singapore': 'SGP', 'Tunisia': 'TUN', 'Ivory Coast': 'CIV', 'Senegal': 'SEN',
        'Madagascar': 'MAD', 'Morocco': 'MAR', 'Zambia': 'ZAM', 'Lithuania': 'LTU', 'Latvia': 'LAT', 'Ukraine': 'UKR',
        'Croatia': 'CRO', 'Malta': 'MLT', 'Israel': 'ISR', 'Cook Islands': 'COK', 'Papua New Guinea': 'PNG',
        'Trinidad and Tobago': 'TTO', 'Jamaica': 'JAM', 'Guyana': 'GUY', 'Austria': 'AUT', 'Denmark': 'DEN', 'Norway': 'NOR',
        'Hungary': 'HUN', 'Moldova': 'MDA', 'Serbia': 'SRB', 'Slovenia': 'SLO', 'Bulgaria': 'BUL', 'Andorra': 'AND',
        'Luxembourg': 'LUX', 'Finland': 'FIN', 'Peru': 'PER', 'Venezuela': 'VEN', 'Ecuador': 'ECU', 'Bermuda': 'BER',
        'Cayman Islands': 'CAY', 'Barbados': 'BAR', 'Bahamas': 'BAH', 'United Arab Emirates': 'UAE', 'India': 'IND',
        'Thailand': 'THA', 'Indonesia': 'INA', 'Chinese Taipei': 'TPE', 'Pakistan': 'PAK', 'Uzbekistan': 'UZB',
        'Nigeria': 'NGA', 'Ghana': 'GHA', 'Botswana': 'BOT', 'Eswatini': 'SWZ', 'Mauritius': 'MRI', 'Rwanda': 'RWA',
        'Burkina Faso': 'BFA', 'Cameroon': 'CMR', 'Algeria': 'ALG', 'Niue': 'NIU', 'Tahiti': 'TAH', 'Vanuatu': 'VAN',
        'Solomon Islands': 'SOL', 'American Samoa': 'ASA', 'Guam': 'GUM', 'Bosnia and Herzegovina': 'BIH', 'Greece': 'GRE',
        'Cyprus': 'CYP', 'Monaco': 'MON', 'Turkey': 'TUR', 'Iran': 'IRI', 'Lebanon': 'LBN', 'Kyrgyzstan': 'KGZ',
        'Mongolia': 'MGL', 'Laos': 'LAO', 'Cambodia': 'CAM', 'Brunei': 'BRU', 'Guatemala': 'GUA', 'Costa Rica': 'CRC',
        'El Salvador': 'SLV', 'Panama': 'PAN', 'Honduras': 'HON', 'Nicaragua': 'NCA', 'Saint Vincent and the Grenadines': 'VIN',
        'Saint Lucia': 'LCA', 'Great Britain': 'GBR'}
# ISO 3166 codes for the flag emoji. England, Scotland and Wales use the subdivision codes the emoji need.
ISO = {'New Zealand': 'nz', 'South Africa': 'za', 'Ireland': 'ie', 'France': 'fr', 'England': 'gb-eng', 'Australia': 'au',
       'Scotland': 'gb-sct', 'Argentina': 'ar', 'Fiji': 'fj', 'Wales': 'gb-wls', 'Italy': 'it', 'Japan': 'jp', 'Georgia': 'ge',
       'United States': 'us', 'Portugal': 'pt', 'Chile': 'cl', 'Spain': 'es', 'Uruguay': 'uy', 'Tonga': 'to', 'Samoa': 'ws',
       'Romania': 'ro', 'Canada': 'ca', 'Hong Kong': 'hk', 'Namibia': 'na', 'Belgium': 'be', 'Netherlands': 'nl',
       'Zimbabwe': 'zw', 'Kazakhstan': 'kz', 'Russia': 'ru', 'Germany': 'de', 'Switzerland': 'ch', 'Czech Republic': 'cz',
       'Poland': 'pl', 'Kenya': 'ke', 'South Korea': 'kr', 'China': 'cn', 'Brazil': 'br', 'Mexico': 'mx', 'Paraguay': 'py',
       'Colombia': 'co', 'Sweden': 'se', 'Uganda': 'ug', 'Philippines': 'ph', 'Sri Lanka': 'lk', 'Malaysia': 'my',
       'Singapore': 'sg', 'Tunisia': 'tn', 'Ivory Coast': 'ci', 'Senegal': 'sn', 'Madagascar': 'mg', 'Morocco': 'ma',
       'Zambia': 'zm', 'Lithuania': 'lt', 'Latvia': 'lv', 'Ukraine': 'ua', 'Croatia': 'hr', 'Malta': 'mt', 'Israel': 'il',
       'Cook Islands': 'ck', 'Papua New Guinea': 'pg', 'Trinidad and Tobago': 'tt', 'Jamaica': 'jm', 'Guyana': 'gy',
       'Austria': 'at', 'Denmark': 'dk', 'Norway': 'no', 'Hungary': 'hu', 'Moldova': 'md', 'Serbia': 'rs', 'Slovenia': 'si',
       'Bulgaria': 'bg', 'Andorra': 'ad', 'Luxembourg': 'lu', 'Finland': 'fi', 'Peru': 'pe', 'Venezuela': 've',
       'Ecuador': 'ec', 'Bermuda': 'bm', 'Cayman Islands': 'ky', 'Barbados': 'bb', 'Bahamas': 'bs',
       'United Arab Emirates': 'ae', 'India': 'in', 'Thailand': 'th', 'Indonesia': 'id', 'Chinese Taipei': 'tw',
       'Pakistan': 'pk', 'Uzbekistan': 'uz', 'Nigeria': 'ng', 'Ghana': 'gh', 'Botswana': 'bw', 'Eswatini': 'sz',
       'Mauritius': 'mu', 'Rwanda': 'rw', 'Burkina Faso': 'bf', 'Cameroon': 'cm', 'Algeria': 'dz', 'Niue': 'nu',
       'Tahiti': 'pf', 'Vanuatu': 'vu', 'Solomon Islands': 'sb', 'American Samoa': 'as', 'Guam': 'gu',
       'Bosnia and Herzegovina': 'ba', 'Greece': 'gr', 'Cyprus': 'cy', 'Monaco': 'mc', 'Turkey': 'tr', 'Iran': 'ir',
       'Lebanon': 'lb', 'Kyrgyzstan': 'kg', 'Mongolia': 'mn', 'Laos': 'la', 'Cambodia': 'kh', 'Brunei': 'bn',
       'Guatemala': 'gt', 'Costa Rica': 'cr', 'El Salvador': 'sv', 'Panama': 'pa', 'Honduras': 'hn', 'Nicaragua': 'ni',
       'Saint Vincent and the Grenadines': 'vc', 'Saint Lucia': 'lc', 'Great Britain': 'gb', 'Bosnia & Herzegovina': 'ba',
       "Cote D'Ivoire": 'ci', 'Gibraltar': 'gi', 'Montenegro': 'me', 'St Vincent and the Grenadines': 'vc',
       'Trinidad & Tobago': 'tt'}


def name(x):
    return ALIAS.get(x, x)


def load(f):
    d = pd.read_csv(f, sep=';', low_memory=False)
    d['date'] = d.date.astype(str).str.replace('/', '-')
    d = d[d.home_score.notna() & d.away_score.notna()].copy()
    for c in ('home_team', 'away_team'):
        d[c] = d[c].map(name)
    return d.sort_values('date', kind='stable')


def form(df, team, n=FORM):
    rows = df[(df.home_team == team) | (df.away_team == team)].tail(n)
    out = []
    for r in rows.itertuples():
        my, op = (r.home_score, r.away_score) if r.home_team == team else (r.away_score, r.home_score)
        out.append('W' if my > op else 'L' if my < op else 'D')
    return ''.join(out)


def num(x):
    return None if pd.isna(x) else int(x)


def tries_of(r, side):
    """A side's tries in one Test, or None when the record doesn't have them (or has an impossible 0)."""
    t, score = num(getattr(r, side + '_tries')), int(getattr(r, side + '_score'))
    if t is None or 5 * t > score: return None
    parts = [num(getattr(r, side + k)) for k in ('_cons', '_pens', '_drops')]
    if t == 0 and score > 0 and all(p is not None for p in parts) and sum(parts) == 0: return None  # blank row, not 0 tries
    if t == 0 and score >= 20: return None
    return t


def meeting(r):
    return [r.date, r.home_team, r.away_team, int(r.home_score), int(r.away_score)]


def h2h(df, a, b):
    """Every Test between a and b: the record, the last ten, biggest wins, typical score and the latest meetings."""
    m = df[((df.home_team == a) & (df.away_team == b)) | ((df.home_team == b) & (df.away_team == a))]
    if m.empty: return None
    def score(r, t): return int(r.home_score) if r.home_team == t else int(r.away_score)
    rows = list(m.itertuples())
    rec = lambda rs: [sum(score(r, a) > score(r, b) for r in rs), sum(score(r, a) == score(r, b) for r in rs),
                      sum(score(r, a) < score(r, b) for r in rs)]
    big = {}
    for t, o in ((a, b), (b, a)):
        wins = [r for r in rows if score(r, t) > score(r, o)]
        if wins: big[t] = meeting(max(wins, key=lambda r: (score(r, t) - score(r, o), r.date)))
    recent = rows[-10:]
    return {'a': a, 'b': b, 'rec': rec(rows), 'last10': rec(recent), 'first': rows[0].date[:4],
            'avg': [round(sum(score(r, a) for r in recent) / len(recent), 1), round(sum(score(r, b) for r in recent) / len(recent), 1)],
            'big': big, 'last': [meeting(r) for r in reversed(rows[-6:])]}


def common_opponents(df, a, b, years=3):
    """How a and b have each done against the teams they've both played in the last few years (not each other):
    per opponent, each side's won/drawn/lost, points for and against, and its latest result against them."""
    since = str(int(TODAY[:4]) - years) + TODAY[4:]
    rec = df[df.date >= since]
    def games(t):
        g = {}
        for r in rec[(rec.home_team == t) | (rec.away_team == t)].itertuples():
            o = r.away_team if r.home_team == t else r.home_team
            my, op = (int(r.home_score), int(r.away_score)) if r.home_team == t else (int(r.away_score), int(r.home_score))
            g.setdefault(o, []).append((r.date, my, op))
        return g
    ga, gb = games(a), games(b)
    shared = [o for o in ga if o in gb and o not in (a, b)]
    if not shared: return None
    def side(gs):
        return [sum(m > o for _, m, o in gs), sum(m == o for _, m, o in gs), sum(m < o for _, m, o in gs),
                sum(m for _, m, _ in gs), sum(o for _, _, o in gs), list(gs[-1])]
    rows = [[o, side(ga[o]), side(gb[o])] for o in shared]
    rows.sort(key=lambda x: -(sum(x[1][:3]) + sum(x[2][:3])))  # most-played first
    return {'since': since, 'opp': rows[:10]}


def kicking_and_more(rows, t):
    """Goal-kicking, discipline, how the points come and the leading try scorers, over the given Tests."""
    out = {}
    def side(r): return 'home' if r.home_team == t else 'away'
    made = att = 0
    for r in rows:
        s = side(r)
        c, ca, p, pa = (num(getattr(r, s + k)) for k in ('_cons', '_cons_att', '_pens', '_pens_att'))
        if None in (c, ca, p, pa) or ca < c or pa < p or ca + pa == 0 or tries_of(r, s) is None: continue
        made += c + p; att += ca + pa
    if att >= 15: out['kick'] = [made, att]
    cards = [(num(getattr(r, side(r) + '_yellow')), num(getattr(r, side(r) + '_red'))) for r in rows]
    cards = [(y, rd or 0) for y, rd in cards if y is not None]
    if len(cards) >= 3: out['cards'] = [sum(y for y, _ in cards), sum(x for _, x in cards), len(cards)]
    tp = sp = 0
    for r in rows:
        s = side(r); t_ = tries_of(r, s); c = num(getattr(r, s + '_cons'))
        if t_ is None or c is None: continue
        tp += 5 * t_ + 2 * c; sp += int(getattr(r, s + '_score'))
    if sp >= 60: out['tryPts'] = round(100 * min(tp, sp) / sp)
    S = collections.Counter()
    for r in rows:
        col = getattr(r, side(r) + '_try_scorers')
        if not isinstance(col, str): continue
        for part in col.split(';'):
            m = re.match(r'\s*(.+?)\s*(?:\((\d+)\))?\s*$', part)
            if m and m.group(1) and m.group(1).lower() != 'penalty try':
                S[m.group(1)] += int(m.group(2) or 1)
    if S: out['scorers'] = [[p, n] for p, n in sorted(S.items(), key=lambda x: (-x[1], x[0]))[:5]]
    return out


def running_records(df):
    """Each team's record at each ground and under each referee, as it stood before every Test, and at the end."""
    G, Rf, grounds, refs = {}, {}, {}, {}
    for r in df.itertuples():
        k = I.ground_key(r.stadium, r.city)
        ref = r.referee.strip() if isinstance(r.referee, str) and r.referee.strip() else None
        if k: grounds[r.Index] = (k, list(G.get((k, r.home_team), [0, 0, 0])), list(G.get((k, r.away_team), [0, 0, 0])))
        if ref: refs[r.Index] = (ref, list(Rf.get((ref, r.home_team), [0, 0, 0])), list(Rf.get((ref, r.away_team), [0, 0, 0])))
        res = 0 if r.home_score > r.away_score else 1 if r.home_score == r.away_score else 2
        for team, i in ((r.home_team, res), (r.away_team, 2 - res)):
            for key, store in ((k, G), (ref, Rf)):
                if key:
                    x = store.setdefault((key, team), [0, 0, 0]); x[i] += 1
    return grounds, refs, G


def extras(r, P, grounds, refs):
    """For a finished Test: the winner's chance beforehand, and both sides' records at the ground and with the
    referee before it."""
    out = {}
    w = I.winner_chance(r, P[r.Index])
    if w is not None: out['pw'] = round(100 * w)
    if r.Index in grounds:
        k, h, a = grounds[r.Index]
        if sum(h) + sum(a): out['gv'] = {'k': k, 'h': h, 'a': a}
    if r.Index in refs:
        k, h, a = refs[r.Index]
        if sum(h) + sum(a) >= 2: out['rv'] = {'k': k, 'h': h, 'a': a}
    return out


def talking_points(df, P, ranked):
    """The year's biggest upsets (among ranked nations) and the leading try scorers across all Tests."""
    year_ago = str(int(TODAY[:4]) - 1) + TODAY[4:]
    rec = df[df.date >= year_ago]
    ups = []
    for r in rec.itertuples():
        w = I.winner_chance(r, P[r.Index])
        if w is None or w >= 0.42 or r.home_team not in ranked or r.away_team not in ranked: continue
        ups.append([r.date, r.home_team, r.away_team, int(r.home_score), int(r.away_score), round(100 * w)])
    ups.sort(key=lambda x: (x[5], x[0]))
    S = collections.Counter()
    games = collections.Counter()
    for r in rec.itertuples():
        for team, col in ((r.home_team, r.home_try_scorers), (r.away_team, r.away_try_scorers)):
            for p, n in I.scorers(col):
                S[(p, team)] += n; games[(p, team)] += 1
    hot = [[p, t, n, games[(p, t)]] for (p, t), n in sorted(S.items(), key=lambda x: (-x[1], x[0][0]))[:15]]
    named = sum(1 for r in rec.itertuples() if isinstance(r.home_try_scorers, str) or isinstance(r.away_try_scorers, str))
    return {'upsets': ups[:10], 'hot': hot, 'hotFrom': [named, len(rec)]}


def team_stats(df, t, P=None):
    """A nation's numbers: all-time record, this year, the last ten Tests' averages, its streak and latest results."""
    rows = list(df[(df.home_team == t) | (df.away_team == t)].itertuples())
    if not rows: return None
    def side(r): return 'home' if r.home_team == t else 'away'
    def other(r): return 'away' if r.home_team == t else 'home'
    def res(r):
        my, op = int(getattr(r, side(r) + '_score')), int(getattr(r, other(r) + '_score'))
        return 'W' if my > op else 'L' if my < op else 'D'
    def wdl(rs): return [sum(res(r) == k for r in rs) for k in 'WDL']
    last = rows[-10:]
    tf = [(tries_of(r, side(r)), tries_of(r, other(r))) for r in last]
    tf = [x for x in tf if None not in x]
    streak = res(rows[-1]); n = 0
    for r in reversed(rows):
        if res(r) != streak: break
        n += 1
    year = TODAY[:4]
    out = {'all': wdl(rows), 'since': rows[0].date[:4], 'year': wdl([r for r in rows if r.date[:4] == year]),
           'last': wdl(last), 'pf': round(sum(int(getattr(r, side(r) + '_score')) for r in last) / len(last), 1),
           'pa': round(sum(int(getattr(r, other(r) + '_score')) for r in last) / len(last), 1), 'n': len(last),
           'streak': '%s%d' % (streak, n),
           'recent': [[r.date, r.away_team if side(r) == 'home' else r.home_team, int(getattr(r, side(r) + '_score')),
                       int(getattr(r, other(r) + '_score')), 'n' if str(r.neutral).upper() == 'TRUE' else side(r)[0],
                       re.sub(r'^\d{4}(–\d{2,4})? ', '', str(r.competition))] for r in reversed(rows[-6:])]}
    # Kicking, discipline and try scorers over the last twelve months (at least the last ten Tests).
    year_ago = str(int(TODAY[:4]) - 1) + TODAY[4:]
    recent12 = [r for r in rows if r.date >= year_ago]
    out.update(kicking_and_more(recent12 if len(recent12) >= len(last) else last, t))
    # The last twelve months Test by Test, with this team's chance beforehand (the "season so far").
    if P is not None:
        out['season'] = [[r.date, r.away_team if side(r) == 'home' else r.home_team, int(getattr(r, side(r) + '_score')),
                          int(getattr(r, other(r) + '_score')), 'n' if I.is_neutral(r) else side(r)[0],
                          round(100 * (P[r.Index] if side(r) == 'home' else 1 - P[r.Index]))] for r in recent12]
    # Scores over the last twenty Tests, oldest first, and close games (decided by 7 or fewer) over three years.
    out['trend'] = [[int(getattr(r, side(r) + '_score')), int(getattr(r, other(r) + '_score'))] for r in rows[-20:]]
    three = str(int(TODAY[:4]) - 3) + TODAY[4:]
    close = [r for r in rows if r.date >= three and abs(int(r.home_score) - int(r.away_score)) <= 7]
    if close: out['close'] = wdl(close)
    if len(tf) >= 3:
        out['tf'] = round(sum(x for x, _ in tf) / len(tf), 1)
        out['ta'] = round(sum(y for _, y in tf) / len(tf), 1)
        out['tn'] = len(tf)
    return out


def details(r):
    """What the record holds about one Test beyond the score: tries, kicks, cards, try scorers, referee, ground, crowd."""
    x = {}
    for s, k in (('home', 'h'), ('away', 'a')):
        t = tries_of(r, s)
        if t is not None:
            x[k + 't'] = t
            for col, key in (('_cons', 'c'), ('_pens', 'p'), ('_drops', 'dg')):
                v = num(getattr(r, s + col))
                if v is not None: x[k + key] = v
        for col, key in (('_yellow', 'y'), ('_red', 'r')):
            v = num(getattr(r, s + col))
            if v is not None: x[k + key] = v
        sc = getattr(r, s + '_try_scorers')
        if isinstance(sc, str) and sc.strip(): x[k + 'sc'] = sc.strip()
    for col, key in (('referee', 'ref'), ('stadium', 'gr'), ('city', 'city')):
        v = getattr(r, col)
        if isinstance(v, str) and v.strip() and v.strip().lower() != 'nan': x[key] = v.strip()
    att = num(r.attendance) if not isinstance(r.attendance, str) else (int(re.sub(r'\D', '', r.attendance)) if re.sub(r'\D', '', r.attendance) else None)
    if att: x['att'] = att
    return x


def nation(t, others):
    o = others.get(t, {})
    nick, p, onp = T10.get(t, ('', o.get('p') or '#2E4A7A', o.get('onp') or '#FFFFFF'))
    code = CODE.get(t) or re.sub(r'[^A-Za-z]', '', t)[:3].upper()
    return {'code': code, 'iso': ISO.get(t, ''), 'p': p, 'onp': onp, 'nick': nick}


def main():
    others = json.load(open('others.json', encoding='utf-8'))
    fx_all = json.load(open('fixtures.json', encoding='utf-8'))
    men_rank = [l.strip().split('|') for l in open('rank30.txt', encoding='utf-8') if l.strip()]
    women_rank = sorted(json.load(open('rankw.json', encoding='utf-8')).items(), key=lambda x: x[1][0])
    res = {'m': load('RugbyResults_AllNations_Detailed.csv'), 'w': load('WomensRugbyResults_Detailed.csv')}
    out = {'asOf': TODAY, 'nations': {}}
    for g in ('m', 'w'):
        ranked = [[r[1], int(r[0]), float(r[2])] for r in men_rank] if g == 'm' else [[t, int(v[0]), float(v[1])] for t, v in women_rank]
        fixtures = []
        for f in fx_all:
            if f.get('g', 'm') != g or f['d'] < TODAY: continue
            fixtures.append({'ko': f.get('ko'), 'd': f['d'], 'h': name(f['h']), 'a': name(f['a']), 'c': f['c'],
                             'v': f.get('v', ''), 'p': f.get('p'), **({'live': 1} if f.get('live') else {})})
        fixtures.sort(key=lambda f: (f['d'], f['ko'] or ''))
        df = res[g]
        P = I.replay(df)
        grounds, refs, G = running_records(df)
        latest = df.tail(RESULTS).iloc[::-1]
        results = [{'d': r.date, 'h': r.home_team, 'a': r.away_team, 'hs': int(r.home_score), 'as': int(r.away_score),
                    'c': re.sub(r'^\d{4}(–\d{2,4})? ', '', str(r.competition)), **details(r),
                    **extras(r, P, grounds, refs)} for r in latest.itertuples()]
        for f in fixtures:
            k = I.ground_key(f['v'])
            if k and (G.get((k, f['h'])) or G.get((k, f['a']))):
                f['gv'] = {'k': k, 'h': G.get((k, f['h']), [0, 0, 0]), 'a': G.get((k, f['a']), [0, 0, 0])}
        teams = {t for t, _, _ in ranked} | {f['h'] for f in fixtures} | {f['a'] for f in fixtures} | \
                {r['h'] for r in results} | {r['a'] for r in results}
        # Head-to-heads for every pair in the fixtures and latest results, keyed by the two names in alphabetical order.
        pairs = {tuple(sorted((x['h'], x['a']))) for x in fixtures + results}
        meets = {'%s|%s' % p: h for p in sorted(pairs) if (h := h2h(df, *p))}
        common = {'%s|%s' % p: x for p in sorted(pairs) if (x := common_opponents(df, *p))}
        out[g] = {'ranked': ranked, 'fixtures': fixtures, 'results': results,
                  'form': {t: form(df, t) for t in sorted(teams)}, 'h2h': meets, 'common': common,
                  'stats': {t: s for t in sorted(teams) if (s := team_stats(df, t, P))},
                  **talking_points(df, P, {t for t, _, _ in ranked})}
        for t in teams:
            out['nations'].setdefault(t, nation(t, others))
    s = json.dumps(out, separators=(',', ':'), ensure_ascii=False, sort_keys=True)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    open(OUT, 'w', encoding='utf-8').write(s)
    print('matchday.json: %d bytes, %d men\'s and %d women\'s fixtures, %d nations'
          % (len(s), len(out['m']['fixtures']), len(out['w']['fixtures']), len(out['nations'])))


if __name__ == '__main__':
    try:
        main()
    except Exception as e:  # keep yesterday's file rather than stopping the whole site build
        print('::warning::app matchday feed not rebuilt (%s: %s); keeping the previous file' % (type(e).__name__, e))
