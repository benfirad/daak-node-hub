#!/usr/bin/env python3

from __future__ import annotations

import importlib.util
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MAIL = ROOT / "macos" / "server-mail"


def load(name: str, path: Path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    assert spec and spec.loader
    spec.loader.exec_module(module)
    return module


class FeedbackTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.feedback = load("brevo_feedback_sync", MAIL / "brevo_feedback_sync.py")

    def test_event_mapping(self):
        self.assertEqual(self.feedback.normalize_event("hardBounce"), "hard")
        self.assertEqual(self.feedback.normalize_event("soft_bounces"), "soft")
        self.assertEqual(self.feedback.normalize_event("spam"), "complaint")
        self.assertEqual(self.feedback.normalize_event("unsubscribed"), "complaint")
        self.assertIsNone(self.feedback.normalize_event("delivered"))

    def test_fingerprint_is_stable(self):
        event = {"email": "a@example.com", "event": "hardBounce", "date": "2026-01-01"}
        self.assertEqual(self.feedback.fingerprint(event), self.feedback.fingerprint(dict(event)))


class SubscriberTests(unittest.TestCase):
    def test_consent_validation(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            source = root / "input.csv"
            source.write_text(
                "email,name,permission,consent_source,consent_at\n"
                "YES@example.com,Yes,yes,trade-fair-form,2026-08-12T10:00:00+02:00\n"
                "no@example.com,No,no,unknown,not-a-date\n",
                encoding="utf-8",
            )
            result = subprocess.run(
                [sys.executable, str(MAIL / "prepare_subscribers.py"), str(source), str(root / "out")],
                check=False,
                capture_output=True,
                text=True,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("accepted=1 rejected=1", result.stdout)
            clean = (root / "out" / "subscribers.clean.csv").read_text(encoding="utf-8")
            rejected = (root / "out" / "rejected.csv").read_text(encoding="utf-8")
            self.assertIn("yes@example.com", clean)
            self.assertIn("permission_missing", rejected)


class ProductionSettingsTests(unittest.TestCase):
    def test_rendered_settings_are_safe(self):
        with tempfile.TemporaryDirectory() as folder:
            key = Path(folder) / "smtp-key"
            key.write_text("secret'value\n", encoding="utf-8")
            env = os.environ.copy()
            env.update(
                SENDING_DOMAIN="news.example.com",
                ROOT_DOMAIN="example.com",
                PUBLIC_HOST="mail.example.com",
                FROM_ADDRESS="fuar@news.example.com",
                REPLY_TO_ADDRESS="hello@example.com",
                FROM_NAME="Example Team",
                LEGAL_FOOTER="Example Company, Example Street 1",
                BREVO_SMTP_USER="smtp-user",
                BREVO_SMTP_KEY_FILE=str(key),
            )
            result = subprocess.run(
                [sys.executable, str(MAIL / "render_production_settings.py")],
                env=env,
                check=True,
                capture_output=True,
                text=True,
            )
            self.assertIn("smtp-relay.brevo.com", result.stdout)
            self.assertIn("privacy.unsubscribe_header", result.stdout)
            self.assertIn("Abonelikten çık", result.stdout)
            self.assertIn("secret''value", result.stdout)
            self.assertNotIn("mailpit", result.stdout)


if __name__ == "__main__":
    unittest.main()
