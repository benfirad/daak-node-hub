#!/bin/zsh
set -euo pipefail

stack_dir="${0:A:h}"
env_file="$stack_dir/.env"

if [[ -e "$env_file" ]]; then
  chmod 600 "$env_file"
  exit 0
fi

umask 077
db_password="$(openssl rand -hex 32)"
listmonk_password="$(openssl rand -base64 32 | tr -d '\n' | tr '/+' '_-')"
stalwart_password="$(openssl rand -base64 32 | tr -d '\n' | tr '/+' '_-')"
portainer_password="$(openssl rand -base64 32 | tr -d '\n' | tr '/+' '_-')"

{
  printf 'LISTMONK_DB_PASSWORD=%s\n' "$db_password"
  printf 'LISTMONK_ADMIN_USER=admin\n'
  printf 'LISTMONK_ADMIN_PASSWORD=%s\n' "$listmonk_password"
  printf 'STALWART_RECOVERY_ADMIN=admin:%s\n' "$stalwart_password"
  printf 'PORTAINER_ADMIN_PASSWORD=%s\n' "$portainer_password"
} > "$env_file"

chmod 600 "$env_file"
print -- "Protected credentials created at $env_file"
