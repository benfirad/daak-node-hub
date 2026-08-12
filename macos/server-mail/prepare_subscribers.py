#!/usr/bin/env python3
"""Validate a consent-bearing CSV before it is imported into listmonk."""

from __future__ import annotations

import csv
import re
import sys
from datetime import datetime
from pathlib import Path


EMAIL_RE = re.compile(r"^[^\s@]+@[^\s@]+\.[^\s@]+$")
REQUIRED = {"email", "name", "permission", "consent_source", "consent_at"}
YES = {"1", "true", "yes", "evet", "confirmed"}
FORBIDDEN_SOURCES = {"bought", "purchased", "scraped", "unknown", "satın alındı", "kazındı"}


def valid_datetime(value: str) -> bool:
    try:
        datetime.fromisoformat(value.replace("Z", "+00:00"))
        return True
    except ValueError:
        return False


def main() -> int:
    if len(sys.argv) != 3:
        print(f"usage: {sys.argv[0]} input.csv output-directory", file=sys.stderr)
        return 2
    source = Path(sys.argv[1])
    output = Path(sys.argv[2])
    output.mkdir(parents=True, exist_ok=True)
    accepted: list[dict[str, str]] = []
    rejected: list[dict[str, str]] = []
    seen: set[str] = set()

    with source.open(newline="", encoding="utf-8-sig") as handle:
        reader = csv.DictReader(handle)
        fields = set(reader.fieldnames or [])
        missing = REQUIRED - fields
        if missing:
            raise SystemExit("missing required columns: " + ", ".join(sorted(missing)))
        for row in reader:
            email = row["email"].strip().lower()
            reason = ""
            if not EMAIL_RE.match(email):
                reason = "invalid_email"
            elif email in seen:
                reason = "duplicate"
            elif row["permission"].strip().lower() not in YES:
                reason = "permission_missing"
            elif not row["consent_source"].strip():
                reason = "consent_source_missing"
            elif row["consent_source"].strip().lower() in FORBIDDEN_SOURCES:
                reason = "unsafe_source"
            elif not valid_datetime(row["consent_at"].strip()):
                reason = "invalid_consent_at"
            row = {key: (value or "").strip() for key, value in row.items()}
            row["email"] = email
            if reason:
                row["rejection_reason"] = reason
                rejected.append(row)
                continue
            seen.add(email)
            accepted.append(row)

    all_fields = list(dict.fromkeys([*(reader.fieldnames or []), "rejection_reason"]))
    with (output / "subscribers.clean.csv").open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=reader.fieldnames or [])
        writer.writeheader()
        writer.writerows(accepted)
    with (output / "consent-ledger.csv").open("w", newline="", encoding="utf-8") as handle:
        ledger_fields = ["email", "consent_source", "consent_at", "permission"]
        writer = csv.DictWriter(handle, fieldnames=ledger_fields)
        writer.writeheader()
        writer.writerows({key: row[key] for key in ledger_fields} for row in accepted)
    with (output / "rejected.csv").open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=all_fields)
        writer.writeheader()
        writer.writerows(rejected)
    print(f"accepted={len(accepted)} rejected={len(rejected)}")
    return 0 if accepted else 3


if __name__ == "__main__":
    raise SystemExit(main())
