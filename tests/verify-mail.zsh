#!/bin/zsh
set -euo pipefail

repo_root="${0:A:h:h}"
mail_root="$repo_root/macos/server-mail"

for script in "$mail_root"/*.zsh; do
  /bin/zsh -n "$script"
done

for script in "$mail_root"/*.py; do
  /usr/bin/python3 -m py_compile "$script"
done

/usr/bin/python3 "$repo_root/tests/test_mail_helpers.py"

/usr/bin/plutil -lint "$mail_root/launchd/com.redmono.server-mail.ensure.plist"

if /usr/bin/grep -RIE --exclude='.env.example' '(ghp_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|sk-[A-Za-z0-9]{20,}|BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY)' "$mail_root"; then
  print -u2 -- "Potential secret found in mail stack"
  exit 1
fi

/usr/bin/grep -q 'location /' "$mail_root/public-gateway.conf"
/usr/bin/grep -q 'return 404' "$mail_root/public-gateway.conf"
/usr/bin/grep -q 'privacy.unsubscribe_header' "$mail_root/render_production_settings.py"
/usr/bin/grep -q 'BounceTypeComplaint\|complaint' "$mail_root/brevo_feedback_sync.py"
/usr/bin/grep -q '\\if :production_enabled' "$mail_root/listmonk-safe-settings.sql"

print -- "Mail stack static checks passed"
