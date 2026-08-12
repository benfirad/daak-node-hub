#!/usr/bin/env python3
"""Poll Brevo delivery events and feed bounces/complaints into listmonk."""

from __future__ import annotations

import base64
import hashlib
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path


BREVO_EVENTS_URL = "https://api.brevo.com/v3/smtp/statistics/events"
RETAINED_FINGERPRINTS = 20000


def read_secret(path: str) -> str:
    value = Path(path).read_text(encoding="utf-8").strip()
    if not value:
        raise RuntimeError(f"secret file is empty: {path}")
    return value


def normalize_event(value: str) -> str | None:
    event = "".join(ch for ch in value.lower() if ch.isalnum())
    if event in {"hardbounce", "hardbounces", "blocked", "invalid"}:
        return "hard"
    if event in {"softbounce", "softbounces", "deferred"}:
        return "soft"
    if event in {"spam", "spamreport", "spamreports", "unsubscribed"}:
        return "complaint"
    return None


def fingerprint(event: dict) -> str:
    stable = "\0".join(
        str(event.get(key, ""))
        for key in ("date", "email", "event", "messageId", "reason")
    )
    return hashlib.sha256(stable.encode("utf-8")).hexdigest()


def load_state(path: Path) -> dict:
    try:
        state = json.loads(path.read_text(encoding="utf-8"))
        if isinstance(state, dict) and isinstance(state.get("processed"), list):
            return state
    except (FileNotFoundError, json.JSONDecodeError):
        pass
    return {"processed": []}


def save_state(path: Path, processed: list[str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temp = path.with_suffix(".tmp")
    temp.write_text(
        json.dumps({"processed": processed[-RETAINED_FINGERPRINTS:]}, indent=2) + "\n",
        encoding="utf-8",
    )
    temp.replace(path)


def fetch_events(api_key: str) -> list[dict]:
    query = urllib.parse.urlencode({"days": 2, "limit": 5000, "sort": "asc"})
    request = urllib.request.Request(
        f"{BREVO_EVENTS_URL}?{query}",
        headers={"accept": "application/json", "api-key": api_key},
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        payload = json.load(response)
    events = payload.get("events", [])
    if not isinstance(events, list):
        raise RuntimeError("Brevo returned an invalid events payload")
    return events


def post_bounce(base_url: str, user: str, token: str, event: dict, bounce_type: str) -> None:
    auth = base64.b64encode(f"{user}:{token}".encode("utf-8")).decode("ascii")
    payload = {
        "email": str(event.get("email", "")).strip().lower(),
        "source": f"brevo:{event.get('event', 'unknown')}",
        "type": bounce_type,
        "meta": json.dumps(
            {
                "date": event.get("date"),
                "message_id": event.get("messageId"),
                "reason": event.get("reason"),
            },
            separators=(",", ":"),
        ),
    }
    if not payload["email"]:
        return
    request = urllib.request.Request(
        f"{base_url.rstrip('/')}/webhooks/bounce",
        data=json.dumps(payload).encode("utf-8"),
        method="POST",
        headers={
            "Authorization": f"Basic {auth}",
            "Content-Type": "application/json",
            "User-Agent": "mya-l11-brevo-feedback/1",
        },
    )
    with urllib.request.urlopen(request, timeout=20) as response:
        if response.status != 200:
            raise RuntimeError(f"listmonk returned HTTP {response.status}")


def sync_once() -> tuple[int, int]:
    api_key = read_secret(os.environ["BREVO_API_KEY_FILE"])
    token = read_secret(os.environ["LISTMONK_API_TOKEN_FILE"])
    user = os.environ.get("LISTMONK_API_USER", "brevo-bounce")
    base_url = os.environ.get("LISTMONK_URL", "http://listmonk:9000")
    state_path = Path(os.environ.get("STATE_FILE", "/state/feedback-state.json"))
    state = load_state(state_path)
    processed_list = list(state["processed"])
    processed = set(processed_list)
    sent = 0

    events = fetch_events(api_key)
    for event in events:
        bounce_type = normalize_event(str(event.get("event", "")))
        event_id = fingerprint(event)
        if not bounce_type or event_id in processed:
            continue
        post_bounce(base_url, user, token, event, bounce_type)
        processed.add(event_id)
        processed_list.append(event_id)
        sent += 1

    save_state(state_path, processed_list)
    heartbeat = Path(os.environ.get("HEARTBEAT_FILE", "/state/heartbeat"))
    heartbeat.write_text(f"{int(time.time())}\n", encoding="ascii")
    return len(events), sent


def run_forever() -> None:
    delay = max(60, int(os.environ.get("POLL_SECONDS", "300")))
    while True:
        try:
            seen, sent = sync_once()
            print(f"feedback sync ok: events={seen} forwarded={sent}", flush=True)
        except (OSError, RuntimeError, urllib.error.URLError) as exc:
            print(f"feedback sync failed: {exc}", file=sys.stderr, flush=True)
        time.sleep(delay)


if __name__ == "__main__":
    if len(sys.argv) == 2 and sys.argv[1] == "once":
        print("events=%d forwarded=%d" % sync_once())
    elif len(sys.argv) == 2 and sys.argv[1] == "run":
        run_forever()
    else:
        raise SystemExit(f"usage: {sys.argv[0]} once|run")
