#!/usr/bin/env python3
"""Create or inspect a Brevo sending domain and print its exact DNS records."""

from __future__ import annotations

import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path


API = "https://api.brevo.com/v3/senders/domains"


def request(api_key: str, method: str, path: str = "", body: dict | None = None) -> dict:
    data = json.dumps(body).encode("utf-8") if body is not None else None
    req = urllib.request.Request(
        API + path,
        data=data,
        method=method,
        headers={"accept": "application/json", "content-type": "application/json", "api-key": api_key},
    )
    with urllib.request.urlopen(req, timeout=30) as response:
        return json.load(response)


def get_or_create(api_key: str, domain: str) -> dict:
    quoted = "/" + urllib.parse.quote(domain, safe="")
    try:
        return request(api_key, "GET", quoted)
    except urllib.error.HTTPError as exc:
        if exc.code != 404:
            raise
    request(api_key, "POST", body={"name": domain})
    return request(api_key, "GET", quoted)


def print_records(config: dict) -> None:
    print(f"domain={config.get('domain') or config.get('domain_name')}")
    print(f"verified={str(bool(config.get('verified'))).lower()}")
    print(f"authenticated={str(bool(config.get('authenticated'))).lower()}")
    print("\nTYPE\tHOST\tVALUE\tREADY")
    for record in config.get("dns_records", {}).values():
        print(
            f"{record.get('type', '')}\t{record.get('host_name', '')}\t"
            f"{record.get('value', '')}\t{str(bool(record.get('status'))).lower()}"
        )


def main() -> int:
    if len(sys.argv) != 3:
        print(f"usage: {sys.argv[0]} sending-domain api-key-file", file=sys.stderr)
        return 2
    domain = sys.argv[1].strip().lower().rstrip(".")
    api_key = Path(sys.argv[2]).read_text(encoding="utf-8").strip()
    if not api_key or "." not in domain:
        raise SystemExit("invalid domain or empty API key")
    if os.environ.get("CHECK_ONLY") == "1":
        config = request(api_key, "GET", "/" + urllib.parse.quote(domain, safe=""))
    else:
        config = get_or_create(api_key, domain)
    runtime = Path(os.environ.get("RUNTIME_DIR", ".runtime"))
    runtime.mkdir(mode=0o700, parents=True, exist_ok=True)
    output = runtime / "brevo-domain-dns.json"
    if os.environ.get("CHECK_ONLY") != "1":
        output.write_text(json.dumps(config, indent=2) + "\n", encoding="utf-8")
        output.chmod(0o600)
    print_records(config)
    if os.environ.get("CHECK_ONLY") != "1":
        print(f"\nSaved provider response: {output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
