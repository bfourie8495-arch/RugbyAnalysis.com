"""Live score test: poll one match from Highlightly, publish site/live.json + site/live.html
to rugbyanalysis.com via wrangler after every poll. Key comes from HIGHLIGHTLY_API_KEY, never printed."""
import json, os, sys, time, datetime as dt, subprocess, urllib.request, urllib.parse

KEY = os.environ.get("HIGHLIGHTLY_API_KEY", "").strip()
HOME, AWAY = os.environ["HOME_TEAM"], os.environ["AWAY_TEAM"]
START = os.environ.get("START_UTC", "")          # HH:MM, poll start (UTC)
MINUTES = int(os.environ.get("MINUTES", "125"))
EVERY = int(os.environ.get("INTERVAL", "90"))    # seconds between polls
ESPN_LG = os.environ.get("ESPN_LEAGUE", "17567")  # ESPN Nations Championship (score cross-check only)
KO_ACTUAL = os.environ.get("KO_ACTUAL", "")      # HH:MM UTC the match really kicked off, if known
if not KEY:
    sys.exit("HIGHLIGHTLY_API_KEY is not set")
utc = lambda: dt.datetime.now(dt.timezone.utc)

PAGE = """<!doctype html><html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1"><title>Live | RugbyAnalysis.com</title>
<style>body{margin:0;font-family:system-ui,sans-serif;background:#f4efe6;color:#14213d}
main{max-width:560px;margin:0 auto;padding:24px 16px}.k{font:700 12px/1 system-ui;letter-spacing:.12em;
text-transform:uppercase;color:#a07a1f}.card{background:#fff;border-radius:14px;padding:22px;margin-top:14px;
box-shadow:0 1px 3px #0002}.row{display:flex;justify-content:space-between;align-items:center;gap:12px}
.t{font-size:20px;font-weight:700}.s{font-size:44px;font-weight:800;font-variant-numeric:tabular-nums}
.st{margin-top:12px;font-weight:600}.dot{display:inline-block;width:9px;height:9px;border-radius:50%;
background:#d22;margin-right:6px;animation:p 1.4s infinite}@keyframes p{50%{opacity:.25}}
.m{color:#6b6b6b;font-size:13px;margin-top:14px}a{color:#14213d}</style></head><body><main>
<div class="k">RugbyAnalysis.com &middot; live score test</div><div class="card" id="c">Loading&hellip;</div>
<p class="m">Test feature. Scores refresh about every 90 seconds and can lag the broadcast.
<a href="/">Back to the site</a></p></main><script>
const e=s=>String(s??'').replace(/[&<>]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;'}[c]));
async function go(){try{const d=await (await fetch('/live.json?t='+Date.now(),{cache:'no-store'})).json();
const sc=String(d.score||'').split(/\\s*[-:]\\s*/);const live=d.live;
let mn=parseInt(d.clock);if(live&&!isNaN(mn)&&/half/i.test(d.status)&&!/half.?time/i.test(d.status))
if(!/\\+/.test(d.clock))mn+=Math.min(2,Math.max(0,Math.floor((Date.now()-new Date(d.updated))/60000)));const ck=live&&!isNaN(mn)?` &middot; ${mn}${/\\+/.test(d.clock)?'+':''}&prime;`:'';
document.getElementById('c').innerHTML=`<div class="k">${e(d.league)}</div>
<div class="row" style="margin-top:14px"><span class="t">${e(d.home)}</span><span class="s">${e(sc[0]??'')}</span></div>
<div class="row"><span class="t">${e(d.away)}</span><span class="s">${e(sc[1]??'')}</span></div>
<div class="st">${live?'<span class="dot"></span>':''}${e(d.status||'Not started')}${ck}</div>
<div class="m">Checked ${new Date(d.updated).toLocaleTimeString()}</div>`}catch(x){
document.getElementById('c').textContent='No live match right now.'}}go();setInterval(go,30000)</script></body></html>"""

HEADERS = "\n/live.json\n  Cache-Control: no-store\n/live.html\n  Cache-Control: no-cache\n"


def fetch():
    q = urllib.parse.urlencode({"homeTeamName": HOME, "awayTeamName": AWAY, "season": 2026, "limit": 5})
    req = urllib.request.Request("https://rugby.highlightly.net/matches?" + q,
                                 headers={"x-rapidapi-key": KEY, "x-rapidapi-host": "rugby.highlightly.net"})
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.load(r)["data"], r.headers.get("x-ratelimit-requests-remaining")


def hhmm(v):
    h, mi = map(int, v.split(":"))
    return utc().replace(hour=h, minute=mi, second=0, microsecond=0)


HALF = {"first": hhmm(KO_ACTUAL) if KO_ACTUAL else None, "second": None}


def match_clock(desc):
    """Minutes played, counted from when each half was first seen live (or the known kick-off)."""
    d, now = desc.lower(), utc()
    if "first half" in d:
        HALF["first"] = HALF["first"] or now
        mins = int((now - HALF["first"]).total_seconds() // 60) + 1
        return f"{mins}'" if mins <= 40 else "40+'"
    if "second half" in d:
        HALF["second"] = HALF["second"] or now
        mins = 41 + int((now - HALF["second"]).total_seconds() // 60)
        return f"{mins}'" if mins <= 80 else "80+'"
    return None


def espn():
    """Match minute from ESPN's public scoreboard (no key, no quota). Returns {} if unavailable."""
    day = utc().strftime("%Y%m%d")
    for host in ("site.web.api.espn.com", "site.api.espn.com"):
        try:
            url = f"https://{host}/apis/site/v2/sports/rugby/{ESPN_LG}/scoreboard?dates={day}"
            with urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"}), timeout=15) as r:
                events = json.load(r).get("events", [])
            break
        except Exception:
            events = []
    for ev in events:
        cs = {c.get("homeAway"): c for c in ev["competitions"][0]["competitors"]}
        if cs.get("home", {}).get("team", {}).get("displayName") == HOME and \
           cs.get("away", {}).get("team", {}).get("displayName") == AWAY:
            st = ev.get("status", {})
            return {"clock": st.get("displayClock"), "period": st.get("period"),
                    "espn_status": st.get("type", {}).get("shortDetail"),
                    "espn_score": f'{cs["home"].get("score")} - {cs["away"].get("score")}'}
    return {}


def sync_site():
    """Brings site/ up to date with main before each deploy. Without this, a match that runs for two
    hours keeps republishing the site as it was when the job started, undoing anything merged or
    refreshed in the meantime (on 6 Nov this took the app's feed and privacy pages offline)."""
    subprocess.run(["git", "fetch", "-q", "--depth=1", "origin", "main"], capture_output=True)
    if subprocess.run(["git", "checkout", "-q", "FETCH_HEAD", "--", "site"], capture_output=True).returncode == 0:
        with open("site/live.html", "w") as f:
            f.write(PAGE)
        with open("site/_headers", "a") as f:  # checkout put back main's _headers without the live rules
            f.write(HEADERS)


def publish(doc):
    sync_site()
    with open("site/live.json", "w") as f:
        json.dump(doc, f)
    r = subprocess.run(["wrangler", "deploy"], capture_output=True, text=True)
    return "ok" if r.returncode == 0 else "DEPLOY FAILED " + (r.stderr or r.stdout)[-300:]


with open("site/live.html", "w") as f:
    f.write(PAGE)
with open("site/_headers", "a") as f:
    f.write(HEADERS)

if START:
    h, m = map(int, START.split(":"))
    t0 = utc().replace(hour=h, minute=m, second=0, microsecond=0)
    if t0 > utc():
        print("waiting until", START, "UTC", flush=True)
        time.sleep((t0 - utc()).total_seconds())

print(f"polling {HOME} v {AWAY} every {EVERY}s for {MINUTES} min", flush=True)
end, last, done = time.time() + MINUTES * 60, None, 0
while time.time() < end and done < 2:
    stamp = utc().strftime("%H:%M:%S")
    try:
        rows, left = fetch()
        exact = [x for x in rows if x["homeTeam"]["name"] == HOME and x["awayTeam"]["name"] == AWAY] or rows
        today = [x for x in exact if x["date"][:10] == utc().strftime("%Y-%m-%d")] or exact[:1]
        m = today[0] if today else {}
        s = m.get("state") or {}
        desc = s.get("description") or ""
        fin = any(w in desc.lower() for w in ("finish", "full", "ended", "after"))
        done += fin
        doc = {"home": m.get("homeTeam", {}).get("name", HOME), "away": m.get("awayTeam", {}).get("name", AWAY),
               "league": (m.get("league") or {}).get("name", ""), "status": desc, "score": s.get("score"),
               "state": s, "live": bool(desc) and not fin and "not started" not in desc.lower(),
               "kickoff": m.get("date"), "updated": utc().isoformat()}
        doc.update(espn())
        doc["espn_clock"], doc["clock"] = doc.get("clock"), match_clock(desc)
        cur = (desc, s.get("score"))
        res = publish(doc)
        print(f"{stamp} {'CHANGE' if cur != last else 'same  '} {cur[0]} | {cur[1]} | ESPN {doc.get('clock')} {doc.get('espn_score')} | quota {left} | {res}",
              flush=True)
        last = cur
    except Exception as ex:
        print(f"{stamp} ERROR {ex}", flush=True)
    time.sleep(EVERY)
print("finished", flush=True)
