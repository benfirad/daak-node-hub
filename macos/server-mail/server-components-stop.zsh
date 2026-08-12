#!/bin/zsh
set -euo pipefail

export PATH="/usr/local/opt/lima/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
export DOCKER_CONTEXT="colima"
stack_dir="${0:A:h}"

compose_args=(
  --env-file "$stack_dir/.env"
  --file "$stack_dir/docker-compose.yml"
)
if [[ -f "$stack_dir/.production.env" ]]; then
  compose_args+=(--env-file "$stack_dir/.production.env" --profile production)
fi
/usr/local/bin/docker compose $compose_args down

/usr/local/bin/colima stop
