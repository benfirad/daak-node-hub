#!/bin/zsh
set -euo pipefail

source_plist="${0:A:h}/launchd/com.redmono.server-mail.ensure.plist"
target_plist="$HOME/Library/LaunchAgents/com.redmono.server-mail.ensure.plist"
domain="gui/$(id -u)"

mkdir -p "$HOME/Library/LaunchAgents" "$HOME/Library/Logs"
/usr/bin/install -m 0644 "$source_plist" "$target_plist"
/usr/bin/plutil -lint "$target_plist"

/bin/launchctl bootout "$domain" "$target_plist" >/dev/null 2>&1 || true
/bin/launchctl bootstrap "$domain" "$target_plist"
/bin/launchctl enable "$domain/com.redmono.server-mail.ensure"
/bin/launchctl kickstart -k "$domain/com.redmono.server-mail.ensure"

print -- "Installed $target_plist"
