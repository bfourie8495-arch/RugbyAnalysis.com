"""Probe 2 of the Highlightly Rugby API (free tier): find specific Tests by team name. ~5 requests."""
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
            return r.status, json.load(r)
    except urllib.error.HTTPError as e:
        return e.code, {"error": e.read().decode()[:300]}

def show(title, **params):
    code, body = get("/matches", limit=20, **params)
    print(f"\n### {title} {params}: HTTP {code} total={body.get('pagination', {}).get('totalCount')}")
    if code != 200:
        print(body); return
    for m in body.get("data", []):
        print(f"- {m['date']} | {m['league']['name']} {m['league']['season']} | "
              f"{m['homeTeam']['name']} v {m['awayTeam']['name']} | {m['state'].get('description')} | {m['state'].get('score')}")

show("Japan v Fiji", homeTeamName="Japan", awayTeamName="Fiji")
show("Fiji v Japan", homeTeamName="Fiji", awayTeamName="Japan")
show("Australia v New Zealand", homeTeamName="Australia", awayTeamName="New Zealand")
show("New Zealand v Australia", homeTeamName="New Zealand", awayTeamName="Australia")
show("Date 16 Oct", date="2026-10-16", countryName="World")
