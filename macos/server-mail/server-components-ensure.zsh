#!/bin/zsh
set -euo pipefail

export PATH="/usr/local/opt/lima/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
export DOCKER_CONTEXT="colima"

stack_dir="${0:A:h}"

if ! /usr/bin/pmset -g batt | /usr/bin/head -1 | /usr/bin/grep -q "AC Power"; then
  print -u2 -- "Charger is disconnected; leaving the UPS battery for existing services."
  exit 0
fi

"$stack_dir/bootstrap-secrets.zsh"

if ! /usr/local/bin/colima status >/dev/null 2>&1; then
  /usr/local/bin/colima start \
    --runtime docker \
    --vm-type vz \
    --cpu 4 \
    --memory 6 \
    --disk 120
fi

compose_args=(
  --env-file "$stack_dir/.env"
  --file "$stack_dir/docker-compose.yml"
)
if [[ -f "$stack_dir/.runtime/production-enabled" && -f "$stack_dir/.production.env" ]]; then
  compose_args+=(--env-file "$stack_dir/.production.env" --profile production)
fi
/usr/local/bin/docker compose $compose_args up --detach --remove-orphans

"$stack_dir/configure-tailnet-serve.zsh"
