"""Tests for alerts.py: run `python -m pytest` in this folder."""

import datetime as dt

import alerts

UTC = dt.timezone.utc

FEED = {
    "m": {
        "ranked": [[t, i + 1, 90 - i] for i, t in enumerate("ABCDEFGHI")],  # A..H top 8, I ninth
        "fixtures": [
            {"d": "2026-11-06", "ko": "2026-11-06T20:10:00Z", "h": "A", "a": "B", "c": "Nations Championship · Round 4", "v": "Dublin", "p": 0.77},
            {"d": "2026-11-07", "ko": "2026-11-07T14:10:00Z", "h": "C", "a": "I", "c": "Test", "v": "", "p": 0.4},
            {"d": "2026-11-07", "ko": "2026-11-07T23:30:00Z", "h": "D", "a": "E", "c": "Test", "v": "", "p": 0.5},
            {"d": "2026-11-14", "ko": "2026-11-14T15:10:00Z", "h": "A", "a": "D", "c": "Test", "v": "", "p": 0.6},
        ],
        "results": [
            {"d": "2026-11-07", "h": "C", "a": "I", "hs": 20, "as": 27, "c": "Test"},
            {"d": "2026-11-01", "h": "A", "a": "C", "hs": 30, "as": 10, "c": "Test"},
        ],
    },
    "w": {"ranked": [], "fixtures": [], "results": []},
}


def test_big_games_are_top_eight_v_top_eight():
    u = {"follows": [], "alerts": {"on": True}, "utcOffsetMinutes": 0}
    assert alerts.reason_for(u, FEED, "m", "A", "B", "2026-11-06") == ("big", None)
    assert alerts.reason_for(u, FEED, "m", "C", "I", "2026-11-07") is None


def test_followed_team_beats_big_game_and_mute_wins():
    u = {"follows": ["m|A"], "alerts": {"on": True}}
    assert alerts.reason_for(u, FEED, "m", "A", "B", "2026-11-06") == ("team", "A")
    u["alerts"]["muted"] = ["m|A"]
    assert alerts.reason_for(u, FEED, "m", "A", "B", "2026-11-06") == ("big", None)


def test_reminder_counts_when_nothing_else_does():
    u = {"follows": [], "alerts": {"on": True, "bigGames": False, "reminders": ["m|2026-11-07|C|I"]}}
    assert alerts.reason_for(u, FEED, "m", "C", "I", "2026-11-07") == ("reminder", None)


def test_weekend_heads_up_covers_the_next_seven_days():
    now = dt.datetime(2026, 11, 5, 18, 0, tzinfo=UTC)  # Thursday 18:00
    u = {"follows": ["m|I"], "alerts": {"on": True}, "utcOffsetMinutes": 0}
    games = alerts.weekend_games(u, FEED, now)
    assert [(g["h"], g["a"]) for g in games] == [("A", "B"), ("C", "I"), ("D", "E")]
    title, body = alerts.heads_up_text(games, 0)
    assert title == "3 games for you this weekend"
    assert body.splitlines()[0] == "Fri 20:10 · A v B"


def test_heads_up_uses_the_users_clock():
    now = dt.datetime(2026, 11, 5, 18, 0, tzinfo=UTC)
    u = {"follows": [], "alerts": {"on": True}, "utcOffsetMinutes": 120}  # e.g. South Africa
    games = alerts.weekend_games(u, FEED, now)
    _, body = alerts.heads_up_text(games, 120)
    assert body.splitlines()[0] == "Fri 22:10 · A v B"


def test_no_heads_up_when_alerts_are_off():
    now = dt.datetime(2026, 11, 5, 18, 0, tzinfo=UTC)
    assert alerts.weekend_games({"follows": ["m|A"], "alerts": {"on": False}}, FEED, now) == []
    assert alerts.weekend_games({"follows": ["m|A"], "alerts": {"on": True, "weekend": False}}, FEED, now) == []


def test_kickoff_reminder_lands_in_exactly_one_window():
    u = {"follows": ["m|A"], "alerts": {"on": True, "kickoffMinutes": 60}, "utcOffsetMinutes": 0}
    hits = []
    t = dt.datetime(2026, 11, 6, 18, 0, tzinfo=UTC)
    while t < dt.datetime(2026, 11, 6, 21, 0, tzinfo=UTC):
        hits += [(t, f["h"]) for f in alerts.kickoff_due(u, FEED, t)]
        t += dt.timedelta(minutes=15)
    assert hits == [(dt.datetime(2026, 11, 6, 19, 0, tzinfo=UTC), "A")]  # 20:10 kick-off, pinged in the 19:00 run


def test_kickoff_reminders_respect_quiet_hours():
    u = {"follows": ["m|D"], "alerts": {"on": True, "kickoffMinutes": 60}, "utcOffsetMinutes": 0}
    now = dt.datetime(2026, 11, 7, 22, 30, tzinfo=UTC)  # D v E kicks off 23:30, reminder at 22:30: quiet
    assert alerts.kickoff_due(u, FEED, now) == []


def test_kickoff_text_has_the_pick():
    f = FEED["m"]["fixtures"][0]
    title, body = alerts.kickoff_text(f, 0)
    assert title == "A v B kicks off at 20:10"
    assert alerts.kickoff_text(f, 120)[0] == "A v B kicks off at 22:10"
    assert body.endswith("Model pick: A, 77%")


def test_full_time_sends_only_new_recent_results():
    today = dt.date(2026, 11, 7)
    new = alerts.new_results(FEED, set(), today)
    assert [r["h"] for _, r in new] == ["C"]  # the 1 Nov result is too old
    assert alerts.new_results(FEED, {"m|2026-11-07|C|I"}, today) == []
    g, r = new[0]
    u = {"follows": ["m|I"], "alerts": {"on": True}, "utcOffsetMinutes": 0}
    assert alerts.full_time_for(u, FEED, g, r, dt.datetime(2026, 11, 7, 16, 0, tzinfo=UTC))
    assert not alerts.full_time_for(u, FEED, g, r, dt.datetime(2026, 11, 7, 23, 0, tzinfo=UTC))  # quiet hours
    assert alerts.full_time_text(r) == ("Full time: C 20–27 I", "I win by 7. Test.")
