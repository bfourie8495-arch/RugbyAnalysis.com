"""Results and fixtures from Wikipedia match boxes ({{Rugbybox}}), for competitions ESPN does not carry.

Wikipedia renders every match on a competition page the same way (a "vevent" block: date, the two teams
and score, the scorers, then venue, attendance and referee), so one parser covers the women's Six
Nations, WXV, Pacific Four, the Pacific Nations Cup, Premiership Women's Rugby and others.
"""
import re
import datetime as dt
from bs4 import BeautifulSoup

API = 'https://en.wikipedia.org/w/api.php'
MONTHS = {m: i + 1 for i, m in enumerate(['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August',
                                           'September', 'October', 'November', 'December'])}


def fetch(session, page):
    """Rendered HTML of a Wikipedia page, or None if it does not exist (yet)."""
    try:
        r = session.get(API, params={'action': 'parse', 'page': page, 'prop': 'text', 'format': 'json', 'redirects': 1}, timeout=60)
        j = r.json()
        return j['parse']['text']['*'] if 'parse' in j else None
    except Exception:
        return None


def _txt(el):
    return re.sub(r'\s+([,.;:)])', r'\1', re.sub(r'\(\s+', '(', re.sub(r'\s+', ' ', el.get_text(' ', strip=True)))).strip() if el else ''


def _date(s):
    """'11 April 2026' -> '2026-04-11'. Undecided dates ('22/23/24 January 2027') take the first day and nd=1."""
    m = re.search(r'(\d{1,2})(?:/\d{1,2})*\s+([A-Z][a-z]+)\s+(\d{4})', s)
    if not m or m.group(2) not in MONTHS:
        return None, 1
    return dt.date(int(m.group(3)), MONTHS[m.group(2)], int(m.group(1))).isoformat(), int('/' in m.group(0))


def _team(td):
    a = [x for x in td.find_all('a') if not x.find_parent(class_='flagicon')]
    a = a[-1] if a else None
    disp = _txt(a) if a else re.sub(r'\(\d BP\)', '', _txt(td)).strip()
    bp = re.search(r'\((\d) BP\)', _txt(td))
    return (a.get('title', disp) if a else disp), disp, int(bp.group(1)) if bp else 0


def _cards(el):
    """(yellow, red) card icons inside an element; a second yellow ('Yellow-red card') counts as a red."""
    y = r = 0
    for im in el.find_all('img'):
        k = (im.get('alt', '') + ' ' + im.get('src', '')).lower().replace('_', ' ')
        if 'yellow-red' in k or 'red card' in k:
            r += 1
        elif 'yellow card' in k:
            y += 1
    return y, r


def _lineups(ev):
    """The two halves (home, away) of the team-sheet table printed under a match box, if there is one."""
    x = ev
    for _ in range(4):
        x = x.find_next_sibling()
        if x is None or 'vevent' in (x.get('class') or []) or 'mw-heading' in (x.get('class') or []) or x.name in ('h2', 'h3', 'h4'):
            return None
        if x.name == 'table':
            halves = [td for td in x.find_all('td') if re.search(r'width:\s*50%', td.get('style', ''))]
            if len(halves) >= 2:
                return halves[:2]
    return None


def _scoring(td):
    """Try scorers and counts from one side's scoring cell."""
    out = {'tries': 0, 'cons': 0, 'cons_att': 0, 'pens': 0, 'pens_att': 0, 'drops': 0, 'drops_att': 0, 'scorers': [], 'cards': None}
    if not td:
        return out
    lines, cur = [], []
    for node in td.children:
        if getattr(node, 'name', None) == 'br':
            lines.append(cur); cur = []
        else:
            cur.append(node)
    lines.append(cur)
    kind = None
    for parts in lines:
        html = ''.join(str(p) for p in parts)
        frag = BeautifulSoup(html, 'html.parser')
        t = _txt(frag)
        if not t:
            continue
        lab = re.match(r'(Try|Tries|Con|Cons|Pen|Pens|Drop|Drops|Cards?)\s*:\s*', t)
        if lab:
            kind = lab.group(1)[:3].lower()
            if kind == 'car':
                out['cards'] = [0, 0]
            t = t[lab.end():]
            b = frag.find('b')
            if b:
                b.decompose()
        if kind == 'car':  # 'Cards:' lines list sin-bins and send-offs, not points
            y, r = _cards(frag)
            out['cards'][0] += y
            out['cards'][1] += r
            continue
        if not t or kind is None:
            continue
        a = frag.find('a')
        name = _txt(a) if a and not re.match(r'penalty try', t, re.I) else re.sub(r'\s*\(.*|\s*\d.*', '', t).strip()
        if kind == 'try':
            n = re.match(r'.*?\((\d+)\)', t)
            n = int(n.group(1)) if n else max(1, len(re.findall(r"\d+(?:\+\d+)?'", t)))
            out['tries'] += n
            out['scorers'].append(('Penalty try' if re.match(r'penalty try', t, re.I) else name) + (f' ({n})' if n > 1 else ''))
        else:
            ma = re.search(r'\((\d+)/(\d+)\)', t)
            made, att = (int(ma.group(1)), int(ma.group(2))) if ma else (len(re.findall(r"\d+(?:\+\d+)?'", t)) or 1,) * 2
            key = {'con': 'cons', 'pen': 'pens', 'dro': 'drops'}[kind]
            out[key] += made
            out[key + '_att'] += att
    return out


def matches(html):
    """Every match box on a page, in page order, with the section heading it sits under as 'stage'."""
    soup = BeautifulSoup(html, 'html.parser')
    for ref in soup.select('sup.reference'):
        ref.decompose()
    out = []
    for ev in soup.select('.vevent'):
        tabs = ev.find_all('table', recursive=False)
        if len(tabs) < 2:
            continue
        head = ev.find_previous(['h2', 'h3', 'h4'])
        top = ev.find_previous('h2')
        when = _txt(tabs[0])
        date, nd = _date(when)
        if not date:
            continue
        tm = re.search(r'(\d{1,2}:\d{2})(?:\s*([A-Z]{2,5}[+\-\d:]*))?', when)
        rows = tabs[1].find_all('tr', recursive=False) or tabs[1].find('tbody').find_all('tr', recursive=False)
        cells = rows[0].find_all('td', recursive=False)
        if len(cells) < 3:
            continue
        hl, hd, hbp = _team(cells[0])
        al, ad, abp = _team(cells[-1])
        tbd = not all(c.find('a') for c in (cells[0], cells[-1]))  # 'Winner SF1', 'First in standings'
        sc = re.match(r'(\d+)\s*[–-]\s*(\d+)', _txt(cells[1]))
        sub = rows[1].find_all('td', recursive=False) if len(rows) > 1 else []
        hs_, as_ = (_scoring(sub[0]), _scoring(sub[-1])) if len(sub) >= 2 else (_scoring(None), _scoring(None))
        info = tabs[2] if len(tabs) > 2 else None
        loc = info.find(class_='location') if info else None
        it = _txt(info)
        att = re.search(r'Attendance:\s*([\d,]+)', it)
        ref = info.find(class_='attendee') if info else None
        ref_t = re.sub(r'\s*\(.*', '', _txt(ref)).strip() if ref else ''
        # cards [home yellow, away yellow, home red, away red]: from the team sheets when printed, else the box's 'Cards:' lines
        lu = _lineups(ev)
        if lu:
            (hy, hr), (ay, ar) = _cards(lu[0]), _cards(lu[1])
            cards = [hy, ay, hr, ar]
        elif hs_['cards'] or as_['cards']:
            hc, ac = hs_['cards'] or [0, 0], as_['cards'] or [0, 0]
            cards = [hc[0], ac[0], hc[1], ac[1]]
        else:
            cards = None
        stad_a = loc.find('a') if loc else None
        loc_t = _txt(loc)
        out.append({
            'stage': _txt(head) if head else '', 'section': _txt(top) if top else '',
            'date': date, 'nd': nd, 'time': (tm.group(1) + (' ' + tm.group(2) if tm.group(2) else '')) if tm else '',
            'home': hl, 'home_name': hd, 'away': al, 'away_name': ad,
            'hs': int(sc.group(1)) if sc else None, 'as': int(sc.group(2)) if sc else None, 'bp': [hbp, abp],
            'h': hs_, 'a': as_,
            'stadium': _txt(stad_a) if stad_a else loc_t.split(',')[0].strip(),
            'city': loc_t.split(',', 1)[1].strip() if ',' in loc_t else '',
            'attendance': int(att.group(1).replace(',', '')) if att else None,
            'referee': ref_t, 'tbd': tbd, 'cards': cards,
        })
    # pages that note cards on most played matches do so on all of them: a match with nothing noted had none
    played = [m for m in out if m['hs'] is not None]
    if played and sum(m['cards'] is not None for m in played) * 2 > len(played):
        for m in played:
            if m['cards'] is None:
                m['cards'] = [0, 0, 0, 0]
    return out


def tables(html):
    """League tables on a page: lists of {nm (team page title), W, D, L, PF, PA, TF, TA, TB, LB, ADJ}."""
    out = []
    for t in BeautifulSoup(html, 'html.parser').select('table.wikitable'):
        trs = t.find_all('tr')
        if not trs:
            continue
        hdr = [_txt(c) for c in trs[0].find_all(['th', 'td'])]
        if not {'Team', 'W', 'PF', 'PA'} <= set(hdr):
            continue
        rows = []
        for tr in trs[1:]:
            cells = tr.find_all(['th', 'td'])
            if len(cells) <= max(hdr.index(k) for k in ('Team', 'W', 'PF', 'PA')):
                continue
            c = dict(zip(hdr, cells))  # trailing cells (a rowspanned 'Qualification' column) may be missing
            a = c['Team'].find('a')
            rows.append({'nm': a.get('title') if a else re.sub(r'\s*\(.*', '', _txt(c['Team'])),
                         **{k: _txt(c[k]) if k in c else '' for k in ['W', 'D', 'L', 'PF', 'PA', 'TF', 'TA', 'TB', 'LB']}, 'ADJ': ''})
        if rows:
            out.append(rows)
    return out


def placings(html, gender_heading):
    """Sevens tournament page: (champion, runner-up) from the 'Final placings' table under the men's or women's heading."""
    soup = BeautifulSoup(html, 'html.parser')
    for h2 in soup.find_all('h2'):
        if not re.match(gender_heading, _txt(h2), re.I):
            continue
        h = h2.find_next(lambda x: x.name in ('h2', 'h3') and (x.name == 'h2' or 'placings' in _txt(x).lower()))
        if not h or h.name == 'h2':
            return None
        t = h.find_next('table')
        names = [_txt(tr.find_all(['td', 'th'])[-1]) for tr in t.find_all('tr')[1:3]]
        return names if len(names) == 2 else None
    return None


def _grid(table):
    """A table's visual grid, following rowspan and colspan: {(row, col): cell}."""
    g = {}
    for r, tr in enumerate(tr for tr in table.find_all('tr') if tr.find_parent('table') is table):
        c = 0
        for cell in tr.find_all(['td', 'th'], recursive=False):
            while (r, c) in g:
                c += 1
            rs = int(re.sub(r'\D', '', cell.get('rowspan', '1')) or 1)
            cs = int(re.sub(r'\D', '', cell.get('colspan', '1')) or 1)
            for i in range(rs):
                for j in range(cs):
                    g[(r + i, c + j)] = cell
            c += cs
    return g


def final_score(html, gender_heading, champion, runner_up):
    """Sevens tournament page: (champion's score, runner-up's score) in the Cup final, read from the knockout bracket."""
    soup = BeautifulSoup(html, 'html.parser')
    for ref in soup.select('sup.reference'):
        ref.decompose()
    for h2 in soup.find_all('h2'):
        if not re.match(gender_heading, _txt(h2), re.I):
            continue
        h = h2.find_next(lambda x: x.name in ('h2', 'h3') and (x.name == 'h2' or re.match(r'(cup|championship|knockout)', _txt(x), re.I)))
        if not h or h.name == 'h2':
            return None
        t = h.find_next('table')
        if not t:
            return None
        g = _grid(t)
        cells, seen = [], set()
        for (r, c), cell in sorted(g.items()):
            if id(cell) in seen:
                continue
            seen.add(id(cell))
            nxt = g.get((r, c + int(re.sub(r'\D', '', cell.get('colspan', '1')) or 1)))
            sc = re.sub(r'\s+', '', nxt.get_text()) if nxt is not None else ''
            if cell.find('a') and re.fullmatch(r'\d+', sc):
                cells.append((c, r, _txt(cell), int(sc)))
        if not cells:
            return None
        last = max(x[0] for x in cells)
        fin = {x[2]: x[3] for x in cells if x[0] == last and x[2] in (champion, runner_up)}
        if len(fin) == 2 and fin[champion] > fin[runner_up]:
            return fin[champion], fin[runner_up]
        return None
    return None
