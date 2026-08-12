#!/bin/zsh
set -euo pipefail

tailscale_bin="/Applications/Tailscale.app/Contents/MacOS/Tailscale"

if [[ ! -x "$tailscale_bin" ]]; then
  print -u2 -- "Tailscale CLI is not installed; loopback-only services remain private."
  exit 0
fi

for port in 8025 8080 9000 9443; do
  "$tailscale_bin" serve --bg --tcp="$port" "tcp://127.0.0.1:$port" >/dev/null
done

print -- "Tailnet-only proxies are active for Mailpit, Stalwart, listmonk and Portainer."
