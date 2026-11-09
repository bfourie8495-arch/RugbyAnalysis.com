"""Chat alerts: who gets one for a new message, and what it says. Pure functions, tested in test_chat.py;
main.py's on_chat_message does the reading and sending.

A room (rooms/{code} in rugbydb) has members (uids), muted (members who turned its alerts off) and names.
Everyone in the room except the sender and those who muted it gets an alert, if alerts are on for them.
Each room's alerts share one notification tag, so a busy room shows its latest message, not fifty.
"""

from __future__ import annotations

MAX_BODY = 140


def recipients(room: dict, sender: str) -> list[str]:
    """The members to alert, in the room's order."""
    muted = set(room.get("muted") or [])
    return [m for m in (room.get("members") or []) if isinstance(m, str) and m and m != sender and m not in muted]


def wants_chat_alerts(user: dict | None) -> bool:
    """Alerts switched on in the app (the same switch as match alerts). No record: no alerts."""
    return bool(((user or {}).get("alerts") or {}).get("on"))


def message_alert(room: dict, message: dict) -> tuple[str, str]:
    """(title, body): 'Saturday rugby' / 'Tom: what a try!'"""
    title = str(room.get("name") or "Chat")[:40]
    name = str(message.get("name") or "Someone")[:24]
    text = " ".join(str(message.get("text") or "").split())
    if len(text) > MAX_BODY:
        text = text[: MAX_BODY - 1].rstrip() + "…"
    return title, f"{name}: {text}"
