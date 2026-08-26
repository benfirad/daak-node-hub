#!/bin/zsh
set -euo pipefail

repository='https://github.com/benfirad/daak-node-hub.git'
archive_base='https://codeload.github.com/benfirad/daak-node-hub/tar.gz'
branch='main'
app="${DAAK_NODE_APP_PATH:-/Applications/daakLOLILE.app}"
state_dir="$HOME/Library/Application Support/DAAK/Updater"
cache_dir="$HOME/Library/Caches/DAAKNodeHub"
log_file="$HOME/Library/Logs/daak-node-updater.log"
lock_dir="$state_dir/.update-lock"
mode="${1:---check}"

mkdir -p "$state_dir" "$cache_dir" "${log_file:h}"

json_result() {
  /usr/bin/python3 - "$1" "$2" "$3" "$4" <<'PY'
import json, sys
print(json.dumps({"status": sys.argv[1], "current": sys.argv[2], "latest": sys.argv[3], "message": sys.argv[4]}, ensure_ascii=False))
PY
}

current='unknown'
current_version='unknown'
current_build='0'
if [[ -r "$app/Contents/Info.plist" ]]; then
  current="$(/usr/libexec/PlistBuddy -c 'Print :DAAKSourceCommit' "$app/Contents/Info.plist" 2>/dev/null || printf unknown)"
  current_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist" 2>/dev/null || printf unknown)"
  current_build="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$app/Contents/Info.plist" 2>/dev/null || printf 0)"
fi

latest="$(/usr/bin/python3 - "$repository" "$branch" "$log_file" <<'PY'
import subprocess, sys

try:
    result = subprocess.run(
        ["/usr/bin/git", "ls-remote", sys.argv[1], f"refs/heads/{sys.argv[2]}"],
        capture_output=True,
        text=True,
        timeout=20,
    )
except subprocess.TimeoutExpired:
    with open(sys.argv[3], "a", encoding="utf-8") as log:
        log.write("GitHub version check timed out after 20 seconds.\n")
    raise SystemExit(0)

if result.stderr:
    with open(sys.argv[3], "a", encoding="utf-8") as log:
        log.write(result.stderr)
if result.returncode == 0 and result.stdout:
    print(result.stdout.split()[0])
PY
)"
if ! printf '%s' "$latest" | /usr/bin/grep -Eq '^[0-9a-f]{40}$'; then
  json_result error "$current" unknown 'GitHub sürüm bilgisi alınamadı.'
  exit 2
fi

if [[ "$current" == "$latest" ]]; then
  json_result current "$current" "$latest" 'DAAK NODE güncel.'
  exit 0
fi

remote_metadata="$(/usr/bin/python3 - "$latest" "$log_file" <<'PY'
import plistlib, sys, urllib.request

url = f"https://raw.githubusercontent.com/benfirad/daak-node-hub/{sys.argv[1]}/macos/Info.plist"
try:
    with urllib.request.urlopen(url, timeout=20) as response:
        info = plistlib.load(response)
    print(f"{info.get('CFBundleShortVersionString', 'unknown')}\t{info.get('CFBundleVersion', '0')}")
except Exception as exc:
    with open(sys.argv[2], "a", encoding="utf-8") as log:
        log.write(f"Remote version metadata failed: {type(exc).__name__}\n")
PY
)"
remote_version="${remote_metadata%%$'\t'*}"
remote_build="${remote_metadata#*$'\t'}"
if [[ -z "$remote_metadata" || "$remote_version" == unknown ]]; then
  json_result error "$current" "$latest" 'GitHub paket sürümü doğrulanamadı; güvenlik için otomatik kurulum durduruldu.'
  exit 2
fi

if [[ "$current_version" != unknown ]] && /usr/bin/python3 - "$current_version" "$current_build" "$remote_version" "$remote_build" <<'PY'
import re, sys

def version(value):
    return tuple(int(part) for part in re.findall(r"\d+", value))

current = (version(sys.argv[1]), version(sys.argv[2]))
remote = (version(sys.argv[3]), version(sys.argv[4]))
raise SystemExit(0 if current > remote else 1)
PY
then
  json_result held "$current" "$latest" "Yerel DAAK NODE v$current_version ($current_build), GitHub v$remote_version ($remote_build) sürümünden daha yeni; otomatik geriye dönüş engellendi."
  exit 0
fi

if [[ "$mode" == '--check' ]]; then
  json_result available "$current" "$latest" 'Yeni DAAK NODE sürümü hazır.'
  exit 0
fi
if [[ "$mode" != '--install' ]]; then
  json_result error "$current" "$latest" 'Geçersiz güncelleme komutu.'
  exit 64
fi

if ! mkdir "$lock_dir" 2>/dev/null; then
  json_result busy "$current" "$latest" 'Başka bir güncelleme zaten çalışıyor.'
  exit 0
fi
work_dir="$(mktemp -d "$cache_dir/update.XXXXXX")"
cleanup() {
  chmod -R u+rwX "$work_dir" 2>/dev/null || true
  case "$work_dir" in "$cache_dir"/update.*) rm -rf "$work_dir" ;; esac
  rmdir "$lock_dir" 2>/dev/null || true
}
trap cleanup EXIT HUP INT TERM

if ! xcrun --find swiftc >/dev/null 2>&1; then
  json_result error "$current" "$latest" 'Apple geliştirici araçları bulunamadı.'
  exit 3
fi

{
  printf '%s update-start current=%s latest=%s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$current" "$latest"
  /usr/bin/curl --fail --silent --show-error --location --retry 2 \
    "$archive_base/$latest" --output "$work_dir/source.tar.gz"
  mkdir -p "$work_dir/source"
  /usr/bin/tar -xzf "$work_dir/source.tar.gz" -C "$work_dir/source" --strip-components=1
  DAAK_NODE_BUILD_DIR="$work_dir/build" DAAK_NODE_SOURCE_COMMIT="$latest" \
    /bin/zsh "$work_dir/source/macos/build.command"
  candidate="$work_dir/build/daakLOLILE.app"
  /usr/bin/codesign --verify --deep --strict "$candidate"
  stamped="$(/usr/libexec/PlistBuddy -c 'Print :DAAKSourceCommit' "$candidate/Contents/Info.plist")"
  [[ "$stamped" == "$latest" ]]

  staging="/Applications/.daakLOLILE.update.$$.app"
  /usr/bin/ditto "$candidate" "$staging"
  /usr/bin/codesign --verify --deep --strict "$staging"

  launch_agent="$HOME/Library/LaunchAgents/app.daaknode.system-ui.plist"
  launch_domain="gui/$(id -u)"
  launch_label='app.daaknode.system-ui'
  /bin/launchctl bootout "$launch_domain/$launch_label" 2>/dev/null || true
  /usr/bin/pkill -x daakLOLILE 2>/dev/null || true

  backup_dir="$cache_dir/previous"
  mkdir -p "$backup_dir"
  backup="$backup_dir/daakLOLILE-$(date -u '+%Y%m%d-%H%M%S').app"
  if [[ -e "$app" ]]; then
    /bin/mv "$app" "$backup"
  fi
  if ! /bin/mv "$staging" "$app"; then
    [[ ! -e "$app" && -e "$backup" ]] && /bin/mv "$backup" "$app"
    /bin/launchctl bootstrap "$launch_domain" "$launch_agent" 2>/dev/null || true
    exit 4
  fi
  /bin/launchctl bootstrap "$launch_domain" "$launch_agent"
  /bin/launchctl kickstart -k "$launch_domain/$launch_label"
  printf '%s update-installed commit=%s backup=%s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$latest" "$backup"
} >>"$log_file" 2>&1

json_result installed "$current" "$latest" 'DAAK NODE güncellendi; uygulama yeniden açılıyor.'
