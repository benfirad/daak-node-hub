#!/usr/bin/env python3
"""Perform credential and public-route checks without sending an e-mail."""

from __future__ import annotations

import base64
import json
import os
import smtplib
import ssl
import sys
import urllib.parse
import urllib.request
from pathlib import Path


def secret(name: str) -> str:
    path = os.environ[name]
    value = Path(path).read_text(encoding="utf-8").strip()
    if not value:
        raise RuntimeError(f"{name} is empty")
    return value


def check_brevo_domain() -> None:
    domain = urllib.parse.quote(os.environ["SENDING_DOMAIN"], safe="")
    request = urllib.request.Request(
        f"https://api.brevo.com/v3/senders/domains/{domain}",
        headers={"accept": "application/json", "api-key": secret("BREVO_API_KEY_FILE")},
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        config = json.load(response)
    if not config.get("verified") or not config.get("authenticated"):
        raise RuntimeError("Brevo reports that the sending domain is not authenticated")
    print("PASS  Brevo reports the sending domain as verified and authenticated")


def check_smtp_login() -> None:
    context = ssl.create_default_context()
    with smtplib.SMTP("smtp-relay.brevo.com", 587, timeout=20) as smtp:
        smtp.ehlo()
        smtp.starttls(context=context)
        smtp.ehlo()
        smtp.login(os.environ["BREVO_SMTP_USER"], secret("BREVO_SMTP_KEY_FILE"))
    print("PASS  Brevo SMTP STARTTLS authentication succeeded without sending")


def check_listmonk_api() -> None:
    user = os.environ.get("LISTMONK_BOUNCE_USER", "brevo-bounce")
    token = secret("LISTMONK_BOUNCE_TOKEN_FILE")
    auth = base64.b64encode(f"{user}:{token}".encode()).decode("ascii")
    request = urllib.request.Request(
        "http://127.0.0.1:9000/api/bounces?per_page=1",
        headers={"accept": "application/json", "Authorization": f"Basic {auth}"},
    )
    with urllib.request.urlopen(request, timeout=10) as response:
        if response.status != 200:
            raise RuntimeError(f"listmonk API returned HTTP {response.status}")
    print("PASS  listmonk feedback API credentials are valid")


def check_public_gateway() -> None:
    host = os.environ["PUBLIC_HOST"]
    with urllib.request.urlopen(f"https://{host}/healthz", timeout=20) as response:
        body = response.read(16).strip()
    if body != b"ok":
        raise RuntimeError("public gateway health response is invalid")
    print("PASS  public HTTPS unsubscribe gateway is reachable")


def main() -> int:
    checks = (check_brevo_domain, check_smtp_login, check_listmonk_api, check_public_gateway)
    failures = 0
    for check in checks:
        try:
            check()
        except Exception as exc:
            failures += 1
            print(f"BLOCK {exc}", file=sys.stderr)
    return 2 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
