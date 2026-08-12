#!/bin/zsh
set -u

mail_domain="${1:-${MAIL_DOMAIN:-}}"
dkim_selector="${2:-${DKIM_SELECTOR:-}}"
relay_host="${3:-${RELAY_HOST:-smtp-relay.brevo.com}}"
docker_bin="${DOCKER_BIN:-/usr/local/bin/docker}"

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

[[ "${MAIL_RELAY_READY:-0}" == 1 ]] && pass "relay credentials were verified" || block "relay credentials are not verified"
[[ "${DOMAIN_AUTH_READY:-0}" == 1 ]] && pass "provider reports domain authentication complete" || block "provider domain authentication is not confirmed"
[[ "${UNSUBSCRIBE_READY:-0}" == 1 ]] && pass "one-click and visible unsubscribe are confirmed" || block "unsubscribe controls are not confirmed"
[[ "${BOUNCE_READY:-0}" == 1 ]] && pass "bounce and suppression handling are confirmed" || block "bounce handling is not confirmed"
[[ "${COMPLAINT_READY:-0}" == 1 ]] && pass "complaint monitoring is confirmed" || block "complaint monitoring is not confirmed"
[[ "${CONSENT_READY:-0}" == 1 ]] && pass "recipient consent source is confirmed" || block "recipient consent source is not confirmed"

print
print -- "Summary: PASS=$pass_count WARN=$warn_count BLOCK=$block_count"
if (( block_count > 0 )); then
  print -- "PRODUCTION_SEND=BLOCKED"
  exit 2
fi

print -- "PRODUCTION_SEND=READY_FOR_SEEDED_TEST_ONLY"
