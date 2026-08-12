#!/bin/zsh
set -euo pipefail

stack_dir="${0:A:h}"
production_env="$stack_dir/.production.env"
docker_bin="${DOCKER_BIN:-/usr/local/bin/docker}"
typeset -i activation_complete=0 settings_switched=0
sql_file=""

cleanup() {
  exit_code=$?
  [[ -z "$sql_file" ]] || /bin/rm -f "$sql_file"
  if (( activation_complete == 0 )); then
    if (( settings_switched == 1 )); then
      "$docker_bin" exec -i listmonk_db psql -v ON_ERROR_STOP=1 --set=production_enabled=0 -U listmonk -d listmonk \
        < "$stack_dir/listmonk-safe-settings.sql" >/dev/null 2>&1 || true
      "$docker_bin" restart listmonk >/dev/null 2>&1 || true
    fi
    if [[ -f "$production_env" ]]; then
      "$docker_bin" compose \
        --env-file "$stack_dir/.env" \
        --env-file "$production_env" \
        --file "$stack_dir/docker-compose.yml" \
        --profile production stop cloudflared public_gateway brevo_feedback >/dev/null 2>&1 || true
    fi
  fi
  return $exit_code
}
trap cleanup EXIT INT TERM

if [[ ! -f "$production_env" ]]; then
  print -u2 -- "Missing $production_env; copy .production.env.example after the domain is connected."
  exit 2
fi
chmod 600 "$production_env"
set -a
source "$production_env"
set +a

required=(ROOT_DOMAIN MAIL_PRODUCTION_ENABLED SENDING_DOMAIN PUBLIC_HOST FROM_NAME FROM_ADDRESS REPLY_TO_ADDRESS LEGAL_FOOTER BREVO_SMTP_USER DKIM_SELECTOR BREVO_API_KEY_FILE BREVO_SMTP_KEY_FILE LISTMONK_BOUNCE_TOKEN_FILE CLOUDFLARE_TUNNEL_TOKEN_FILE CONSENT_LEDGER)
for name in $required; do
  [[ -n "${(P)name:-}" ]] || { print -u2 -- "Missing $name"; exit 2; }
done
[[ "$MAIL_PRODUCTION_ENABLED" == 1 ]] || { print -u2 -- "MAIL_PRODUCTION_ENABLED must be 1"; exit 2; }
for path in "$BREVO_API_KEY_FILE" "$BREVO_SMTP_KEY_FILE" "$LISTMONK_BOUNCE_TOKEN_FILE" "$CLOUDFLARE_TUNNEL_TOKEN_FILE" "$CONSENT_LEDGER"; do
  [[ -s "$stack_dir/${path#./}" ]] || { print -u2 -- "Missing or empty protected file: $path"; exit 2; }
  chmod 600 "$stack_dir/${path#./}"
done

export BREVO_API_KEY_FILE="$stack_dir/${BREVO_API_KEY_FILE#./}"
export BREVO_SMTP_KEY_FILE="$stack_dir/${BREVO_SMTP_KEY_FILE#./}"
export LISTMONK_BOUNCE_TOKEN_FILE="$stack_dir/${LISTMONK_BOUNCE_TOKEN_FILE#./}"
export CLOUDFLARE_TUNNEL_TOKEN_FILE="$stack_dir/${CLOUDFLARE_TUNNEL_TOKEN_FILE#./}"
export CONSENT_LEDGER="$stack_dir/${CONSENT_LEDGER#./}"

"$docker_bin" compose \
  --env-file "$stack_dir/.env" \
  --env-file "$production_env" \
  --file "$stack_dir/docker-compose.yml" \
  --profile production up --detach public_gateway cloudflared

typeset -i gateway_ready=0
for attempt in {1..20}; do
  if /usr/bin/curl --silent --show-error --fail --max-time 10 "https://$PUBLIC_HOST/healthz" | /usr/bin/grep -qx ok; then
    gateway_ready=1
    break
  fi
  /bin/sleep 3
done
(( gateway_ready == 1 )) || { print -u2 -- "Public HTTPS gateway did not become ready"; exit 2; }

"$stack_dir/mail-preflight.zsh" "$SENDING_DOMAIN" "$DKIM_SELECTOR"

sql_file="$(mktemp -t mya-l11-production.XXXXXX)"
umask 077
/usr/bin/python3 "$stack_dir/render_production_settings.py" > "$sql_file"
"$docker_bin" exec -i listmonk_db psql -v ON_ERROR_STOP=1 -U listmonk -d listmonk < "$sql_file"
settings_switched=1
"$docker_bin" restart listmonk >/dev/null

"$docker_bin" compose \
  --env-file "$stack_dir/.env" \
  --env-file "$production_env" \
  --file "$stack_dir/docker-compose.yml" \
  --profile production up --detach --remove-orphans

typeset -i services_ready=0
for attempt in {1..20}; do
  gateway_state="$($docker_bin inspect -f '{{.State.Health.Status}}' mail-public-gateway 2>/dev/null || true)"
  feedback_state="$($docker_bin inspect -f '{{.State.Health.Status}}' mail-brevo-feedback 2>/dev/null || true)"
  tunnel_state="$($docker_bin inspect -f '{{.State.Running}}' mail-cloudflared 2>/dev/null || true)"
  if [[ "$gateway_state" == healthy && "$feedback_state" == healthy && "$tunnel_state" == true ]]; then
    services_ready=1
    break
  fi
  /bin/sleep 3
done
(( services_ready == 1 )) || { print -u2 -- "Production services failed their health checks; Mailpit safety mode restored."; exit 2; }

/usr/bin/touch "$stack_dir/.runtime/production-enabled"
/bin/chmod 600 "$stack_dir/.runtime/production-enabled"
activation_complete=1
print -- "Production services armed. Send only to seed inboxes until the final delivered-message header audit passes."
