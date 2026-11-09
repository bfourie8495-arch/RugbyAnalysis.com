import chat


def test_recipients_skip_sender_and_muted():
    room = {"members": ["a", "b", "c", "d"], "muted": ["c"]}
    assert chat.recipients(room, "a") == ["b", "d"]


def test_recipients_handle_missing_fields():
    assert chat.recipients({}, "a") == []
    assert chat.recipients({"members": ["a", "", None, "b"]}, "a") == ["b"]


def test_wants_chat_alerts():
    assert chat.wants_chat_alerts({"alerts": {"on": True}})
    assert not chat.wants_chat_alerts({"alerts": {"on": False}})
    assert not chat.wants_chat_alerts({})
    assert not chat.wants_chat_alerts(None)


def test_message_alert_text():
    title, body = chat.message_alert({"name": "Saturday rugby"}, {"name": "Tom", "text": "what a\n try!"})
    assert title == "Saturday rugby"
    assert body == "Tom: what a try!"


def test_message_alert_shortens_long_messages():
    _, body = chat.message_alert({}, {"name": "Ana", "text": "x" * 600})
    assert body.startswith("Ana: ")
    assert body.endswith("…")
    assert len(body) <= len("Ana: ") + chat.MAX_BODY
