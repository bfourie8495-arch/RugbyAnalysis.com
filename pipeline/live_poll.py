"""Freshness test: poll one match once a minute and log every change. ~1 request per minute."""
import json, os, sys, time, datetime, urllib.request, urllib.parse, urllib.error

KEY = os.environ.get("HIGHLIGHTLY_API_KEY", "").strip()
HOME, AWAY = os.environ["HOME_TEAM"], os.environ["AWAY_TEAM"]
START = os.environ["START_UTC"]            # e.g. 14:10
MINUTES = int(os.environ.get("MINUTES", "40"))
if not KEY:
    sys.exit("HIGHLIGHTLY_API_KEY is not set")

def fetch():
    q = urllib.parse.urlencode({"homeTeamName": HOME, "awayTeamName": AWAY, "season": 2026, "limit": 5})
    req = urllib.request.Request("https://rugby.highlightly.net/matches?" + q,
                                 headers={"x-rapidapi-key": KEY, "x-rapidapi-host": "rugby.highlightly.net"})
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.load(r)["data"], r.headers.get("x-ratelimit-requests-remaining")

now = datetime.datetime.utcnow()
h, m = map(int, START.split(":"))
start = now.replace(hour=h, minute=m, second=0, microsecond=0)
if start > now:
    time.sleep((start - now).total_seconds())
print(f"polling {HOME} v {AWAY} for {MINUTES} min from {START} UTC", flush=True)
last = None
for i in range(MINUTES):
    t = datetime.datetime.utcnow().strftime("%H:%M:%S")
    try:
        rows, remaining = fetch()
        today = [x for x in rows if x["date"][:10] == datetime.datetime.utcnow().strftime("%Y-%m-%d")] or rows[:1]
        s = today[0]["state"] if today else {}
        cur = (s.get("description"), s.get("score"))
        flag = "CHANGE" if cur != last else "same  "
        print(f"{t} {flag} {cur[0]} | {cur[1]} | quota left {remaining}", flush=True)
        last = cur
    except Exception as e:
        print(f"{t} ERROR {e}", flush=True)
    time.sleep(60)
