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


def _scoring(td):
    """Try scorers and counts from one side's scoring cell."""
    out = {'tries': 0, 'cons': 0, 'cons_att': 0, 'pens': 0, 'pens_att': 0, 'drops': 0, 'drops_att': 0, 'scorers': []}
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
        lab = re.match(r'(Try|Tries|Con|Cons|Pen|Pens|Drop|Drops)\s*:\s*', t)
        if lab:
            kind = lab.group(1)[:3].lower()
            t = t[lab.end():]
            b = frag.find('b')
            if b:
                b.decompose()
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
            'referee': ref_t, 'tbd': tbd,
        })
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
