#!/bin/zsh
set -euo pipefail

root="$(cd "$(dirname "$0")" && pwd)"
repo="$(cd "$root/.." && pwd)"
commit="$(/usr/bin/git -C "$repo" rev-parse HEAD)"
build_dir="${DAAK_NODE_BUILD_DIR:-$HOME/Library/Caches/DAAKNodeHub/bootstrap}"
app='/Applications/daakLOLILE.app'
launch_agent="$HOME/Library/LaunchAgents/app.daaknode.system-ui.plist"
launch_domain="gui/$(id -u)"
launch_label='app.daaknode.system-ui'

DAAK_NODE_BUILD_DIR="$build_dir" DAAK_NODE_SOURCE_COMMIT="$commit" /bin/zsh "$root/build.command"
candidate="$build_dir/daakLOLILE.app"
/usr/bin/codesign --verify --deep --strict "$candidate"

staging="/Applications/.daakLOLILE.bootstrap.$$.app"
/usr/bin/ditto "$candidate" "$staging"
/usr/bin/codesign --verify --deep --strict "$staging"

/bin/launchctl bootout "$launch_domain/$launch_label" 2>/dev/null || true
/usr/bin/pkill -x daakLOLILE 2>/dev/null || true
if [[ -e "$app" ]]; then
  backup_dir="$HOME/Library/Caches/DAAKNodeHub/previous"
  mkdir -p "$backup_dir"
  /bin/mv "$app" "$backup_dir/daakLOLILE-$(date -u '+%Y%m%d-%H%M%S').app"
fi
/bin/mv "$staging" "$app"

mkdir -p "${launch_agent:h}" "$HOME/Library/Logs"
cat > "$launch_agent" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>app.daaknode.system-ui</string>
  <key>ProgramArguments</key><array><string>/Applications/daakLOLILE.app/Contents/MacOS/daakLOLILE</string></array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><dict><key>SuccessfulExit</key><false/></dict>
  <key>ProcessType</key><string>Interactive</string>
  <key>ThrottleInterval</key><integer>15</integer>
  <key>StandardOutPath</key><string>$HOME/Library/Logs/daak-system-ui.log</string>
  <key>StandardErrorPath</key><string>$HOME/Library/Logs/daak-system-ui.log</string>
</dict></plist>
PLIST
/usr/bin/plutil -lint "$launch_agent"
/bin/launchctl bootstrap "$launch_domain" "$launch_agent"
/bin/launchctl kickstart -k "$launch_domain/$launch_label"

echo "DAAK NODE $commit kuruldu; sonraki güncellemeler uygulamanın içinden otomatik yapılacak."
