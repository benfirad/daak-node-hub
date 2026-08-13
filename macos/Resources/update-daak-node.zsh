#!/bin/zsh
set -euo pipefail

repository='https://github.com/benfirad/daak-node-hub.git'
archive_base='https://codeload.github.com/benfirad/daak-node-hub/tar.gz'
branch='main'
app='/Applications/daakLOLILE.app'
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
if [[ -r "$app/Contents/Info.plist" ]]; then
  current="$(/usr/libexec/PlistBuddy -c 'Print :DAAKSourceCommit' "$app/Contents/Info.plist" 2>/dev/null || printf unknown)"
fi

latest="$(/usr/bin/git ls-remote "$repository" "refs/heads/$branch" 2>>"$log_file" | /usr/bin/awk 'NR == 1 { print $1 }')"
if ! printf '%s' "$latest" | /usr/bin/grep -Eq '^[0-9a-f]{40}$'; then
  json_result error "$current" unknown 'GitHub sürüm bilgisi alınamadı.'
  exit 2
fi

if [[ "$current" == "$latest" ]]; then
  json_result current "$current" "$latest" 'DAAK NODE güncel.'
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

  backup_dir="$cache_dir/previous"
  mkdir -p "$backup_dir"
  backup="$backup_dir/daakLOLILE-$(date -u '+%Y%m%d-%H%M%S').app"
  if [[ -e "$app" ]]; then
    /bin/mv "$app" "$backup"
  fi
  if ! /bin/mv "$staging" "$app"; then
    [[ ! -e "$app" && -e "$backup" ]] && /bin/mv "$backup" "$app"
    exit 4
  fi
  printf '%s update-installed commit=%s backup=%s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$latest" "$backup"
} >>"$log_file" 2>&1

(/bin/sleep 2; /usr/bin/open "$app") >/dev/null 2>&1 &!
json_result installed "$current" "$latest" 'DAAK NODE güncellendi; uygulama yeniden açılıyor.'
