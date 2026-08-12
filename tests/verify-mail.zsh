#!/bin/zsh
set -euo pipefail

repo_root="${0:A:h:h}"
mail_root="$repo_root/macos/server-mail"

for script in "$mail_root"/*.zsh; do
  /bin/zsh -n "$script"
done

/usr/bin/plutil -lint "$mail_root/launchd/com.redmono.server-mail.ensure.plist"

if /usr/bin/grep -RIE --exclude='.env.example' '(ghp_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|sk-[A-Za-z0-9]{20,}|BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY)' "$mail_root"; then
  print -u2 -- "Potential secret found in mail stack"
  exit 1
fi

print -- "Mail stack static checks passed"
