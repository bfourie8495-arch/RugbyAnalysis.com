"""Who gets which alert, and what it says. Pure functions with no Firebase, so they're tested directly
(test_alerts.py). The same rules as the app's lib/models/alerts.dart: keep the two in step.

A user (users/{uid} in the rugbydb database) looks like:
    {"follows": ["m|South Africa", "w|England"],
     "alerts": {"on": True, "weekend": True, "bigGames": True, "bigGamesFor": ["m", "w"],
                "kickoffMinutes": 60, "fullTime": True, "muted": [], "reminders": ["m|2026-11-07|Wales|Japan"]},
     "utcOffsetMinutes": 0}
The matchday feed is https://rugbyanalysis.com/app/matchday.json.
"""

from __future__ import annotations

import datetime as dt
from typing import Any, Iterable

BIG_GAME_TOP = 8
QUIET_FROM, QUIET_TO = 22, 7  # no kick-off or full-time pings from 22:00 to 07:00 in the user's time
DAYS = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]


def parse_ko(s: Any) -> dt.datetime | None:
    if not isinstance(s, str) or not s:
        return None
    s = s.replace("Z", "+00:00")
    if len(s) == len("2027-10-01T10:45+00:00"):
        s = s.replace("+00:00", ":00+00:00")
    try:
        return dt.datetime.fromisoformat(s)
    except ValueError:
        return None


def prefs_of(user: dict) -> dict:
    a = user.get("alerts") if isinstance(user.get("alerts"), dict) else {}
    return {
        "on": a.get("on") is True,
        "weekend": a.get("weekend") is not False,
        "bigGames": a.get("bigGames") is not False,
        "bigGamesFor": set(a.get("bigGamesFor") or ["m", "w"]),
        "kickoffMinutes": int(a.get("kickoffMinutes") or 0) if a.get("kickoffMinutes") is not None else 60,
        "fullTime": a.get("fullTime") is not False,
        "muted": set(a.get("muted") or []),
        "reminders": set(a.get("reminders") or []),
    }


def top_teams(feed: dict, g: str) -> set[str]:
    return {r[0] for r in (feed.get(g) or {}).get("ranked", []) if isinstance(r, list) and len(r) >= 2 and r[1] <= BIG_GAME_TOP}


def reason_for(user: dict, feed: dict, g: str, home: str, away: str, date: str) -> tuple[str, str | None] | None:
    """Why this user cares about a game: ('team', team), ('big', None), ('reminder', None), or None."""
    p = prefs_of(user)
    follows = set(user.get("follows") or [])
    for t in (home, away):
        k = f"{g}|{t}"
        if k in follows and k not in p["muted"]:
            return "team", t
    if p["bigGames"] and g in p["bigGamesFor"]:
        top = top_teams(feed, g)
        if home in top and away in top:
            return "big", None
    if f"{g}|{date}|{home}|{away}" in p["reminders"]:
        return "reminder", None
    return None


def fixtures(feed: dict) -> Iterable[tuple[str, dict]]:
    for g in ("m", "w"):
        for f in (feed.get(g) or {}).get("fixtures", []):
            yield g, f


def local(t: dt.datetime, offset_minutes: int) -> dt.datetime:
    return t + dt.timedelta(minutes=offset_minutes)


def day_label(t: dt.datetime) -> str:
    return f"{DAYS[t.weekday()]} {t.day} {MONTHS[t.month - 1]}"


def quiet(t_utc: dt.datetime, offset_minutes: int) -> bool:
    h = local(t_utc, offset_minutes).hour
    return h >= QUIET_FROM or h < QUIET_TO


# ---------------------------------------------------------------- the weekend heads-up (Thursday evening)

def weekend_games(user: dict, feed: dict, now: dt.datetime) -> list[dict]:
    """The games worth watching from now until next Wednesday night, soonest first."""
    if not prefs_of(user)["on"] or not prefs_of(user)["weekend"]:
        return []
    until = now + dt.timedelta(days=7)
    out = []
    for g, f in fixtures(feed):
        ko = parse_ko(f.get("ko"))
        when = ko or parse_ko(f"{f.get('d')}T12:00:00Z")
        if when is None or not (now <= when < until):
            continue
        why = reason_for(user, feed, g, f.get("h", ""), f.get("a", ""), f.get("d", ""))
        if why:
            out.append({**f, "g": g, "why": why[0], "team": why[1], "_t": when, "_timed": ko is not None})
    return sorted(out, key=lambda x: x["_t"])


def heads_up_text(games: list[dict], offset_minutes: int) -> tuple[str, str]:
    n = len(games)
    title = f"{games[0]['h']} v {games[0]['a']} this weekend" if n == 1 else f"{n} games for you this weekend"
    lines = []
    for x in games[:3]:
        t = local(x["_t"], offset_minutes)
        when = f"{DAYS[t.weekday()]} {t:%H:%M}" if x["_timed"] else f"{DAYS[t.weekday()]}, time TBC"
        lines.append(f"{when} · {x['h']} v {x['a']}")
    if n > 3:
        lines.append(f"+{n - 3} more")
    return title, "\n".join(lines)


# ---------------------------------------------------------------- kick-off reminders (every 15 minutes)

def kickoff_due(user: dict, feed: dict, now: dt.datetime, window_minutes: int = 15) -> list[dict]:
    """Games whose reminder falls in [now, now + window): each game is reminded exactly once."""
    p = prefs_of(user)
    mins = p["kickoffMinutes"]
    if not p["on"] or mins <= 0:
        return []
    offset = int(user.get("utcOffsetMinutes") or 0)
    out = []
    for g, f in fixtures(feed):
        ko = parse_ko(f.get("ko"))
        if ko is None:
            continue
        ping = ko - dt.timedelta(minutes=mins)
        if not (now <= ping < now + dt.timedelta(minutes=window_minutes)) or quiet(ping, offset):
            continue
        why = reason_for(user, feed, g, f.get("h", ""), f.get("a", ""), f.get("d", ""))
        if why:
            out.append({**f, "g": g, "why": why[0], "team": why[1]})
    return out


def kickoff_text(f: dict, offset_minutes: int) -> tuple[str, str]:
    """The kick-off time in the user's own time: reminders go out up to 15 minutes early, so a time is
    always right where "in 1 hour" might not be."""
    ko = parse_ko(f.get("ko"))
    at = f" at {local(ko, offset_minutes):%H:%M}" if ko else " soon"
    title = f"{f['h']} v {f['a']} kicks off{at}"
    body = " · ".join(x for x in [f.get("c", ""), f.get("v", "")] if x)
    p = f.get("p")
    if isinstance(p, (int, float)):
        pick, chance = (f["h"], p) if p >= 0.5 else (f["a"], 1 - p)
        body += f"\nModel pick: {pick}, {round(chance * 100)}%"
    return title, body


# ---------------------------------------------------------------- full-time scores (when the feed has them)

def result_key(g: str, r: dict) -> str:
    return f"{g}|{r.get('d')}|{r.get('h')}|{r.get('a')}"


def new_results(feed: dict, already_sent: set[str], today: dt.date) -> list[tuple[str, dict]]:
    """Results from today or yesterday not announced yet. Older ones are never sent, so a first run
    (or a long outage) can't flood anyone with old scores."""
    since = (today - dt.timedelta(days=1)).isoformat()
    out = []
    for g in ("m", "w"):
        for r in (feed.get(g) or {}).get("results", []):
            if (r.get("d") or "") >= since and result_key(g, r) not in already_sent:
                out.append((g, r))
    return out


def full_time_for(user: dict, feed: dict, g: str, r: dict, now: dt.datetime) -> bool:
    p = prefs_of(user)
    if not p["on"] or not p["fullTime"] or quiet(now, int(user.get("utcOffsetMinutes") or 0)):
        return False
    return reason_for(user, feed, g, r.get("h", ""), r.get("a", ""), r.get("d", "")) is not None


def full_time_text(r: dict) -> tuple[str, str]:
    hs, as_ = r.get("hs", 0), r.get("as", 0)
    title = f"Full time: {r['h']} {hs}–{as_} {r['a']}"
    if hs == as_:
        body = "A draw."
    else:
        winner, margin = (r["h"], hs - as_) if hs > as_ else (r["a"], as_ - hs)
        body = f"{winner} win by {margin}."
    return title, (body + (f" {r['c']}." if r.get("c") else "")).strip()
