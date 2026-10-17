"""One-off probe of the Highlightly Rugby API (free tier). Uses ~4 of the 100 daily requests.
Key is read from the HIGHLIGHTLY_API_KEY environment variable and is never printed."""
import json, os, sys, urllib.request, urllib.parse, urllib.error

KEY = os.environ.get("HIGHLIGHTLY_API_KEY", "").strip()
if not KEY:
    sys.exit("HIGHLIGHTLY_API_KEY is not set")
BASE = "https://rugby.highlightly.net"

def get(path, **params):
    url = f"{BASE}{path}?{urllib.parse.urlencode(params)}"
    req = urllib.request.Request(url, headers={"x-rapidapi-key": KEY,
                                               "x-rapidapi-host": "rugby.highlightly.net"})
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            hdrs = {k: v for k, v in r.headers.items() if "limit" in k.lower() or "remaining" in k.lower()}
            return r.status, hdrs, json.load(r)
    except urllib.error.HTTPError as e:
        return e.code, {}, {"error": e.read().decode()[:300]}

for d in sys.argv[1:] or ["2026-10-17", "2026-10-24", "2026-11-06"]:
    code, hdrs, body = get("/matches", date=d, limit=100)
    print(f"\n=== date {d}: HTTP {code} rate headers {hdrs}")
    if code != 200:
        print(body); continue
    print("plan:", body.get("plan"), "| total:", body.get("pagination", {}).get("totalCount"))
    for m in body.get("data", []):
        lg = m["league"]["name"]
        print(f"- {lg} ({m['league']['season']}): {m['homeTeam']['name']} v {m['awayTeam']['name']}"
              f" | {m['state'].get('description')} | {m['state'].get('score')} | {m['date']}")
