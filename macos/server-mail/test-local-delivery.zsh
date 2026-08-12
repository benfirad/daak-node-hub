#!/bin/zsh
set -euo pipefail

export PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
test_id="mya-l11-$(date -u +%Y%m%dT%H%M%SZ)"
message_file="$(mktemp -t mya-l11-mail.XXXXXX)"
trap '/bin/rm -f "$message_file"' EXIT

printf '%s\n' \
  'From: MYA-L11 Test <noreply@redmono.test>' \
  'To: Seed Inbox <seed@redmono.test>' \
  "Subject: MYA-L11 local delivery $test_id" \
  "Message-ID: <$test_id@redmono.test>" \
  "Date: $(LC_ALL=C date -R)" \
  '' \
  "Local-only delivery test: $test_id" > "$message_file"

/usr/bin/curl --silent --show-error --fail \
  --url smtp://127.0.0.1:1025 \
  --mail-from noreply@redmono.test \
  --mail-rcpt seed@redmono.test \
  --upload-file "$message_file"

if /usr/bin/curl --silent --show-error --fail http://127.0.0.1:8025/api/v1/messages \
  | /usr/bin/grep -q "$test_id"; then
  print -- "PASS local SMTP delivery captured by Mailpit: $test_id"
else
  print -u2 -- "FAIL Mailpit did not return test message: $test_id"
  exit 1
fi
