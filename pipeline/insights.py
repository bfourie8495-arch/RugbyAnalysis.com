"""The interesting numbers behind the app's stats, from the results CSVs.

- replay(df): every Test's pre-match chances, from a replay of World Rugby's ranking system over the whole
  history (each side starts at 50; points move by the published rules: home advantage 3, the gap capped
  at 10, 1.5x for a win by more than 15, 2x at a World Cup). The same chance formula as the app's picks.
- ground_key: one name per ground, whatever its sponsor was called at the time.
- scorers: try scorers from the record's 'Name (2); Name' strings.
"""
import collections, re

import pandas as pd

HOME = 3


def chance(rh, ra, neutral):
    """The home side's chance of winning, as the app's picks work it out."""
    return 1 / (1 + 10 ** (-((rh + (0 if neutral else HOME)) - ra) / 10 * 0.6))


def is_neutral(r):
    return str(r.neutral).strip().upper() == 'TRUE'


def replay(df):
    """{row index: home side's pre-match chance} for every Test, oldest first."""
    R = collections.defaultdict(lambda: 50.0)
    out = {}
    for r in df.itertuples():
        h, a = r.home_team, r.away_team
        neutral = is_neutral(r)
        out[r.Index] = chance(R[h], R[a], neutral)
        d = max(-10, min(10, R[h] + (0 if neutral else HOME) - R[a]))
        hs, as_ = int(r.home_score), int(r.away_score)
        change = 1 - d / 10 if hs > as_ else -d / 10 if hs == as_ else -(1 + d / 10)
        mult = (1.5 if abs(hs - as_) > 15 else 1) * (2 if re.search(r'Rugby World Cup(?! .*[Qq]ualif)', str(r.competition)) else 1)
        R[h] += change * mult
        R[a] -= change * mult
    return out


def winner_chance(r, p_home):
    """The winner's pre-match chance (0 to 1), or None for a draw."""
    if r.home_score == r.away_score: return None
    return p_home if r.home_score > r.away_score else 1 - p_home


ALIASES = {
    'allianz stadium|london': 'Twickenham', 'twickenham stadium': 'Twickenham', 'twickenham': 'Twickenham',
    'scottish gas murrayfield': 'Murrayfield', 'murrayfield stadium': 'Murrayfield', 'murrayfield': 'Murrayfield',
    'principality stadium': 'Millennium Stadium', 'millennium stadium': 'Millennium Stadium', 'millennium': 'Millennium Stadium',
    'aviva stadium': 'Lansdowne Road', 'lansdowne road': 'Lansdowne Road',
    'accor stadium|sydney': 'Stadium Australia', 'anz stadium|sydney': 'Stadium Australia', 'telstra stadium|sydney': 'Stadium Australia',
    'stadium australia': 'Stadium Australia',
    'ellis park stadium': 'Ellis Park', 'ellis park': 'Ellis Park', 'emirates airline park': 'Ellis Park',
    'loftus versfeld stadium': 'Loftus Versfeld', 'loftus versfeld': 'Loftus Versfeld',
    'dhl stadium': 'Cape Town Stadium', 'cape town stadium': 'Cape Town Stadium',
    'newlands stadium': 'Newlands', 'newlands': 'Newlands',
    'westpac stadium': 'Wellington Regional Stadium', 'westpactrust stadium': 'Wellington Regional Stadium',
    'sky stadium': 'Wellington Regional Stadium', 'wellington regional stadium': 'Wellington Regional Stadium',
    'kings park stadium|durban': 'Kings Park', 'kings park|durban': 'Kings Park', 'absa stadium|durban': 'Kings Park',
    'hollywoodbets kings park|durban': 'Kings Park',
    'lang park': 'Lang Park', 'suncorp stadium': 'Lang Park',
    'docklands stadium': 'Docklands Stadium', 'marvel stadium': 'Docklands Stadium', 'etihad stadium': 'Docklands Stadium',
    'stadio luigi ferraris': 'Stadio Luigi Ferraris', 'bluenergy stadium': 'Stadio Friuli', 'stadio friuli': 'Stadio Friuli',
    'stade de france': 'Stade de France', 'stadio olimpico|rome': 'Stadio Olimpico', 'eden park': 'Eden Park',
}


def ground_key(stadium, city=''):
    """One name per ground: 'Allianz Stadium, London' and 'Twickenham' are both 'Twickenham'."""
    if not isinstance(stadium, str) or not stadium.strip() or stadium.strip().lower() in ('venue tbc', 'nan'): return None
    name = stadium.strip()
    if not city and ',' in name:
        name, city = (x.strip() for x in name.split(',', 1))
    n, c = name.lower(), (city or '').strip().lower() if isinstance(city, str) else ''
    return ALIASES.get('%s|%s' % (n, c)) or ALIASES.get(n) or name


def scorers(col):
    """[(name, tries)] from 'Kolbe (2); Arendse; Penalty try'."""
    out = []
    if not isinstance(col, str): return out
    for part in col.split(';'):
        m = re.match(r'\s*(.+?)\s*(?:\((\d+)\))?\s*$', part)
        if m and m.group(1) and m.group(1).lower() != 'penalty try':
            out.append((m.group(1), int(m.group(2) or 1)))
    return out


def record(rows, team):
    """[won, drawn, lost] for team over rows."""
    w = d = l = 0
    for r in rows:
        my, op = (r.home_score, r.away_score) if r.home_team == team else (r.away_score, r.home_score)
        if my > op: w += 1
        elif my == op: d += 1
        else: l += 1
    return [w, d, l]
