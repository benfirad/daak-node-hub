#!/usr/bin/env python3
"""Render secret-bearing listmonk production settings as SQL on stdout."""

from __future__ import annotations

import json
import os
import re
import sys
from html import escape
from pathlib import Path


HOST_RE = re.compile(r"^(?=.{1,253}$)(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,63}$")
EMAIL_RE = re.compile(r"^[^\s@]+@[^\s@]+\.[^\s@]+$")


def sql_literal(value: str) -> str:
    return "'" + value.replace("'", "''") + "'"


def secret(path: str) -> str:
    value = Path(path).read_text(encoding="utf-8").strip()
    if not value:
        raise SystemExit(f"empty secret file: {path}")
    return value


def main() -> int:
    root_domain = os.environ["ROOT_DOMAIN"].lower().rstrip(".")
    sending_domain = os.environ["SENDING_DOMAIN"].lower().rstrip(".")
    public_host = os.environ["PUBLIC_HOST"].lower().rstrip(".")
    from_address = os.environ["FROM_ADDRESS"].strip().lower()
    reply_to = os.environ["REPLY_TO_ADDRESS"].strip().lower()
    from_name = os.environ["FROM_NAME"].strip()
    legal_footer = os.environ["LEGAL_FOOTER"].strip()
    smtp_user = os.environ["BREVO_SMTP_USER"].strip()
    if not HOST_RE.match(root_domain) or not HOST_RE.match(sending_domain) or not HOST_RE.match(public_host):
        raise SystemExit("invalid sending domain or public host")
    if not sending_domain.endswith("." + root_domain) or not public_host.endswith("." + root_domain):
        raise SystemExit("SENDING_DOMAIN and PUBLIC_HOST must be subdomains of ROOT_DOMAIN")
    if not EMAIL_RE.match(from_address) or not from_address.endswith("@" + sending_domain):
        raise SystemExit("FROM_ADDRESS must belong to SENDING_DOMAIN")
    if not EMAIL_RE.match(reply_to):
        raise SystemExit("REPLY_TO_ADDRESS must be a valid monitored mailbox")
    if not from_name or not legal_footer or not smtp_user:
        raise SystemExit("FROM_NAME, LEGAL_FOOTER and BREVO_SMTP_USER are required")

    smtp = [{
        "host": "smtp-relay.brevo.com",
        "name": "brevo-production",
        "port": 587,
        "uuid": "",
        "enabled": True,
        "password": secret(os.environ["BREVO_SMTP_KEY_FILE"]),
        "tls_type": "starttls",
        "username": smtp_user,
        "max_conns": 1,
        "idle_timeout": "15s",
        "wait_timeout": "10s",
        "auth_protocol": "login",
        "email_headers": {"Reply-To": reply_to},
        "from_addresses": [f"{from_name} <{from_address}>"],
        "hello_hostname": sending_domain,
        "max_msg_retries": 2,
        "msg_retry_delay": "10s",
        "tls_skip_verify": False,
    }]
    values = {
        "app.root_url": f"https://{public_host}",
        "app.from_email": f"{from_name} <{from_address}>",
        "app.message_rate": 1,
        "app.concurrency": 1,
        "app.send_optin_confirmation": True,
        "bounce.enabled": True,
        "bounce.webhooks_enabled": True,
        "bounce.actions": {
            "soft": {"count": 3, "action": "none"},
            "hard": {"count": 1, "action": "blocklist"},
            "complaint": {"count": 1, "action": "blocklist"},
        },
        "privacy.unsubscribe_header": True,
        "privacy.allow_blocklist": True,
        "privacy.allow_preferences": True,
        "privacy.record_optin_ip": True,
        "privacy.individual_tracking": False,
        "privacy.disable_tracking": True,
        "smtp": smtp,
    }
    print("BEGIN;")
    for key, value in values.items():
        encoded = json.dumps(value, ensure_ascii=False, separators=(",", ":"))
        print(
            "INSERT INTO settings (key, value) VALUES "
            f"({sql_literal(key)}, {sql_literal(encoded)}::jsonb) "
            "ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;"
        )
    template = f"""<!doctype html>
<html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"></head>
<body style="margin:0;background:#f5f5f5;font-family:Arial,sans-serif;color:#222">
<table role="presentation" width="100%"><tr><td align="center" style="padding:24px">
<table role="presentation" width="100%" style="max-width:640px;background:#fff"><tr><td style="padding:32px">
{{{{ template "content" . }}}}
<hr style="border:0;border-top:1px solid #ddd;margin:32px 0 16px">
<p style="font-size:12px;line-height:1.5;color:#666">{escape(from_name)}<br>{escape(legal_footer)}</p>
<p style="font-size:12px;line-height:1.5"><a href="{{{{ UnsubscribeURL }}}}">Abonelikten çık</a> · <a href="{{{{ MessageURL }}}}">Tarayıcıda görüntüle</a></p>
</td></tr></table></td></tr></table></body></html>"""
    print(
        "UPDATE templates SET body = " + sql_literal(template) + ", updated_at = NOW() "
        "WHERE type = 'campaign' AND is_default = TRUE;"
    )
    print("COMMIT;")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
