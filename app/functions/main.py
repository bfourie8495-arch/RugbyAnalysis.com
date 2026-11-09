"""RugbyAnalysis app alerts: three scheduled Cloud Functions (plus on_chat_message, below) that read the website's matchday feed and send
push notifications through Firebase Cloud Messaging. The decisions (who, when, what it says) are in
alerts.py; this file only reads Firestore, fetches the feed and sends.

Deploy from the app folder (this is its own "rugby" codebase, so Smack Bang's functions are never touched):
    firebase deploy --project middle-509820 --only functions:rugby
"""

from __future__ import annotations

import datetime as dt
import logging

import requests
from firebase_admin import firestore, initialize_app, messaging
from firebase_functions import firestore_fn, scheduler_fn
from firebase_functions.options import set_global_options

import alerts
import chat

initialize_app()
set_global_options(max_instances=2)

DATABASE = "rugbydb"
REGION = "europe-west2"
FEED_URL = "https://rugbyanalysis.com/app/matchday.json"
LONDON = scheduler_fn.Timezone("Europe/London")

log = logging.getLogger(__name__)


def _db():
    return firestore.client(database_id=DATABASE)


def _feed() -> dict:
    r = requests.get(FEED_URL, timeout=20)
    r.raise_for_status()
    return r.json()


def _users_with_alerts(db):
    """(uid, user) for everyone with alerts switched on."""
    for snap in db.collection("users").where("alerts.on", "==", True).stream():
        yield snap.id, snap.to_dict() or {}


def _send(db, uid: str, kind: str, title: str, body: str, data: dict | None = None, tag: str | None = None) -> bool:
    """Send to the phone saved for uid. Never raises; removes tokens Firebase says are dead."""
    try:
        ref = db.collection("devices").document(uid)
        snap = ref.get()
        token = (snap.to_dict() or {}).get("token") if snap.exists else None
        if not isinstance(token, str) or not token:
            return False
        msg = messaging.Message(
            token=token,
            notification=messaging.Notification(title=title, body=body),
            data={"type": kind, **{k: str(v) for k, v in (data or {}).items()}},
            android=messaging.AndroidConfig(
                priority="high",
                # A tag replaces the last notification with the same tag (one per chat room).
                notification=messaging.AndroidNotification(tag=tag) if tag else None,
            ),
        )
        try:
            messaging.send(msg)
            return True
        except (messaging.UnregisteredError, messaging.SenderIdMismatchError):
            log.info("Removing a dead device token")
            ref.delete()
    except Exception:  # noqa: BLE001 - one failed alert must never stop the rest
        log.exception("Alert to %s failed", uid)
    return False


@scheduler_fn.on_schedule(schedule="0 18 * * 4", timezone=LONDON, region=REGION)
def weekend_heads_up(_event: scheduler_fn.ScheduledEvent) -> None:
    """Thursday 18:00 UK time: this weekend's games for each user."""
    db, feed, now = _db(), _feed(), dt.datetime.now(dt.timezone.utc)
    sent = 0
    for uid, user in _users_with_alerts(db):
        games = alerts.weekend_games(user, feed, now)
        if games:
            title, body = alerts.heads_up_text(games, int(user.get("utcOffsetMinutes") or 0))
            sent += _send(db, uid, "weekend", title, body)
    log.info("Weekend heads-up sent to %d phones", sent)


@scheduler_fn.on_schedule(schedule="*/15 * * * *", timezone=LONDON, region=REGION)
def kickoff_reminders(_event: scheduler_fn.ScheduledEvent) -> None:
    """Every 15 minutes: reminders that fall in the next 15 minutes (an hour or 15 minutes before kick-off)."""
    db, feed = _db(), _feed()
    now = dt.datetime.now(dt.timezone.utc).replace(second=0, microsecond=0)
    now -= dt.timedelta(minutes=now.minute % 15)  # line up with the quarter hour, so each game lands in one run
    for uid, user in _users_with_alerts(db):
        offset = int(user.get("utcOffsetMinutes") or 0)
        for f in alerts.kickoff_due(user, feed, now):
            title, body = alerts.kickoff_text(f, offset)
            _send(db, uid, "kickoff", title, body, {"g": f["g"], "h": f["h"], "a": f["a"], "d": f["d"]})


@scheduler_fn.on_schedule(schedule="*/30 * * * *", timezone=LONDON, region=REGION)
def full_time_scores(_event: scheduler_fn.ScheduledEvent) -> None:
    """Every 30 minutes: new results in the feed (it updates twice a day) to everyone who'd want them."""
    db, feed = _db(), _feed()
    now = dt.datetime.now(dt.timezone.utc)
    log_ref = db.collection("sent").document("results")
    already = set((log_ref.get().to_dict() or {}).get("keys", []))
    fresh = alerts.new_results(feed, already, now.date())
    if not fresh:
        return
    users = list(_users_with_alerts(db))
    for g, r in fresh:
        title, body = alerts.full_time_text(r)
        for uid, user in users:
            if alerts.full_time_for(user, feed, g, r, now):
                _send(db, uid, "result", title, body, {"g": g, "h": r["h"], "a": r["a"], "d": r["d"]})
    # Remember what's been announced (only recent keys, so the document stays small).
    since = (now.date() - dt.timedelta(days=3)).isoformat()
    keep = sorted(k for k in already | {alerts.result_key(g, r) for g, r in fresh} if k.split("|")[1] >= since)
    log_ref.set({"keys": keep, "updatedAt": firestore.SERVER_TIMESTAMP})


@firestore_fn.on_document_created(document="rooms/{room}/messages/{message}", database=DATABASE, region=REGION)
def on_chat_message(event: firestore_fn.Event[firestore_fn.DocumentSnapshot | None]) -> None:
    """A new chat message: alert the room's other members (not those who muted it). Rules in chat.py."""
    if event.data is None:
        return
    message = event.data.to_dict() or {}
    room_id = event.params["room"]
    db = _db()
    snap = db.collection("rooms").document(room_id).get()
    if not snap.exists:
        return
    room = snap.to_dict() or {}
    title, body = chat.message_alert(room, message)
    sent = 0
    for uid in chat.recipients(room, str(message.get("uid") or "")):
        user = db.collection("users").document(uid).get()
        if not chat.wants_chat_alerts(user.to_dict() if user.exists else None):
            continue
        if _send(db, uid, "chat", title, body, {"room": room_id}, tag="room-" + room_id):
            sent += 1
    log.info("Chat message in %s: %d alerts", room_id, sent)
