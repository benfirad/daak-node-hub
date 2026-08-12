#!/bin/zsh
set -euo pipefail

export PATH="/usr/local/opt/lima/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
export DOCKER_CONTEXT="colima"
stack_dir="${0:A:h}"

/usr/local/bin/docker compose \
  --env-file "$stack_dir/.env" \
  --file "$stack_dir/docker-compose.yml" \
  down

/usr/local/bin/colima stop
