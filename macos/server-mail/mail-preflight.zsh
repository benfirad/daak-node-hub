#!/bin/zsh
set -u

mail_domain="${1:-${MAIL_DOMAIN:-}}"
dkim_selector="${2:-${DKIM_SELECTOR:-}}"
relay_host="${3:-${RELAY_HOST:-smtp-relay.brevo.com}}"
docker_bin="${DOCKER_BIN:-/usr/local/bin/docker}"
stack_dir="${0:A:h}"

typeset -i pass_count=0 warn_count=0 block_count=0
pass() { (( pass_count += 1 )); print -- "PASS  $1"; }
warn() { (( warn_count += 1 )); print -- "WARN  $1"; }
block() { (( block_count += 1 )); print -- "BLOCK $1"; }

container_running() {
  "$docker_bin" inspect -f '{{.State.Running}}' "$1" 2>/dev/null | /usr/bin/grep -qx true
}

txt_record() {
  /usr/bin/dig +short TXT "$1" 2>/dev/null | /usr/bin/tr -d '"'
}

print -- "MAIL PRODUCTION PREFLIGHT"
print -- "Time: $(/bin/date -u '+%Y-%m-%dT%H:%M:%SZ')"
print -- "Mode: read-only; a green result permits seeded tests, not bulk sending."
print

for name in listmonk listmonk_db mailpit; do
  if container_running "$name"; then pass "$name is running"; else block "$name is not running"; fi
done

if "$docker_bin" logs --tail 150 listmonk 2>&1 | /usr/bin/grep -q 'initialized email (SMTP) messenger: @mailpit'; then
  pass "listmonk is locked to the Mailpit test sink"
else
  warn "listmonk is not using Mailpit; verify the authenticated relay and rate limit"
fi

if /usr/bin/nc -G 4 -z "$relay_host" 587 >/dev/null 2>&1; then
  pass "authenticated relay is reachable on TCP/587 ($relay_host)"
else
  block "authenticated relay is unreachable on TCP/587 ($relay_host)"
fi

if [[ -n "${CONSENT_LEDGER:-}" ]] && [[ -s "$CONSENT_LEDGER" ]] && \
  /usr/bin/awk -F, 'NR == 1 {for (i=1;i<=NF;i++) h[$i]=1} END {exit !(NR > 1 && h["email"] && h["consent_source"] && h["consent_at"] && h["permission"])}' "$CONSENT_LEDGER"; then
  pass "consent ledger is present and has at least one recipient"
else
  block "a validated consent ledger is missing or empty"
fi

if [[ -n "${BREVO_API_KEY_FILE:-}" && -n "${BREVO_SMTP_KEY_FILE:-}" && -n "${LISTMONK_BOUNCE_TOKEN_FILE:-}" && -n "${PUBLIC_HOST:-}" ]]; then
  if /usr/bin/python3 "$stack_dir/production_preflight.py"; then
    pass "provider credentials, feedback API and public HTTPS route are valid"
  else
    block "one or more provider/public-route checks failed"
  fi
else
  block "production credential files and PUBLIC_HOST are not configured"
fi

if [[ -z "$mail_domain" ]]; then
  block "sending subdomain is not provided"
else
  txt_record "$mail_domain" | /usr/bin/grep -qi 'v=spf1' && pass "$mail_domain has SPF" || block "$mail_domain has no SPF"
  txt_record "_dmarc.$mail_domain" | /usr/bin/grep -qi 'v=DMARC1' && pass "$mail_domain has DMARC" || block "$mail_domain has no DMARC"
  if [[ -n "$dkim_selector" ]] && txt_record "$dkim_selector._domainkey.$mail_domain" | /usr/bin/grep -Eqi '(v=DKIM1|p=)'; then
    pass "$mail_domain has DKIM ($dkim_selector)"
  else
    block "$mail_domain DKIM selector is missing or unresolved"
  fi
fi

print
print -- "Summary: PASS=$pass_count WARN=$warn_count BLOCK=$block_count"
if (( block_count > 0 )); then
  print -- "PRODUCTION_SEND=BLOCKED"
  exit 2
fi

print -- "PRODUCTION_SEND=READY_FOR_SEEDED_TEST_ONLY"
