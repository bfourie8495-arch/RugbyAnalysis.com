"""Build the app's matchday feed: World Rugby rankings, upcoming Tests with the model's pick, the latest results,
each nation's recent form, and each nation's colours, short code and flag (as an ISO code the app turns into a
flag emoji). Men's and women's internationals. Writes ../site/app/matchday.json, served at
https://rugbyanalysis.com/app/matchday.json for the RugbyAnalysis app.

Runs from build_all.py after update.py. If anything goes wrong, the previous file is kept and the run shows a
yellow warning instead of stopping the rest of the site build."""
import json, os, re, datetime
import pandas as pd

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
                             'v': f.get('v', ''), 'p': f.get('p')})
        fixtures.sort(key=lambda f: (f['d'], f['ko'] or ''))
        df = res[g]
        latest = df.tail(RESULTS).iloc[::-1]
        results = [{'d': r.date, 'h': r.home_team, 'a': r.away_team, 'hs': int(r.home_score), 'as': int(r.away_score),
                    'c': re.sub(r'^\d{4}(–\d{2,4})? ', '', str(r.competition))} for r in latest.itertuples()]
        teams = {t for t, _, _ in ranked} | {f['h'] for f in fixtures} | {f['a'] for f in fixtures} | \
                {r['h'] for r in results} | {r['a'] for r in results}
        out[g] = {'ranked': ranked, 'fixtures': fixtures, 'results': results,
                  'form': {t: form(df, t) for t in sorted(teams)}}
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
