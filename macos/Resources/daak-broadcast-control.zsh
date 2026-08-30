#!/bin/zsh
set -euo pipefail

ROOT="$HOME/Library/Application Support/DAAK/Broadcast"
PID_FILE="$ROOT/m3-obs.pid"
RELAY_PID_FILE="$ROOT/m3-srt-relay.pid"
STATE_FILE="$ROOT/state.json"
QUALITY_FILE="$ROOT/quality-profile"
OBS_PROFILE="$HOME/Library/Application Support/obs-studio/basic/profiles/DAAK Sender Thunderbolt/basic.ini"
OBS_SCENE="$HOME/Library/Application Support/obs-studio/basic/scenes/DAAK M3 Sender.json"
RELAY="$ROOT/bin/daak-srt-relay"
NODE_CONFIG="$HOME/Library/Application Support/DAAK/node-config.json"
RECEIVER_COMMAND='$HOME/Library/Application\ Support/DAAK/Broadcast/daak-broadcast-receiver.zsh'

configured_host() {
  local key="$1"
  [[ -f "$NODE_CONFIG" ]] || return 1
  /usr/bin/python3 - "$NODE_CONFIG" "$key" <<'PY'
import json
import sys

try:
    with open(sys.argv[1], encoding="utf-8") as handle:
        value = json.load(handle).get(sys.argv[2], "")
except (OSError, ValueError):
    raise SystemExit(1)
if not isinstance(value, str) or not value.strip():
    raise SystemExit(1)
print(value.strip())
PY
}

DIRECT_HOST="${DAAK_BROADCAST_DIRECT_HOST:-$(configured_host thunderboltHost 2>/dev/null || true)}"
TAIL_HOST="${DAAK_BROADCAST_TAIL_HOST:-$(configured_host tailHost 2>/dev/null || true)}"

route() {
  if [[ -n "$DIRECT_HOST" ]] && /usr/bin/nc -z -G 1 "$DIRECT_HOST" 22 >/dev/null 2>&1; then
    print -r -- direct
  elif [[ -n "$TAIL_HOST" ]] && /usr/bin/nc -z -G 2 "$TAIL_HOST" 22 >/dev/null 2>&1; then
    print -r -- tailscale
  else
    print -r -- offline
  fi
}

quality_selection() {
  local selected="1440p60"
  [[ -f "$QUALITY_FILE" ]] && selected="$(<"$QUALITY_FILE")"
  case "$selected" in
    1080p60|1440p60) print -r -- "$selected" ;;
    *) print -r -- 1440p60 ;;
  esac
}

apply_direct_quality() {
  local selected="$1"
  /usr/bin/python3 - "$selected" "$OBS_PROFILE" "$OBS_SCENE" <<'PY'
import json
import os
from pathlib import Path
import re
import sys
import tempfile

selected, profile_name, scene_name = sys.argv[1:]
presets = {
    "1080p60": {"width": 1920, "height": 1080, "bitrate": 40000},
    "1440p60": {"width": 2560, "height": 1440, "bitrate": 80000},
}
if selected not in presets:
    raise SystemExit("unsupported quality")
profile_path = Path(profile_name)
scene_path = Path(scene_name)
if not profile_path.is_file() or not scene_path.is_file():
    raise SystemExit("OBS broadcast profile or scene is missing")
preset = presets[selected]

profile = profile_path.read_text(encoding="utf-8")
values = {
    "FFVBitrate": preset["bitrate"],
    "BaseCX": preset["width"],
    "BaseCY": preset["height"],
    "OutputCX": preset["width"],
    "OutputCY": preset["height"],
    "FPSCommon": 60,
}
for key, value in values.items():
    profile, count = re.subn(
        rf"(?m)^{re.escape(key)}=.*$",
        f"{key}={value}",
        profile,
        count=1,
    )
    if count != 1:
        raise SystemExit(f"missing OBS setting: {key}")

scene = json.loads(scene_path.read_text(encoding="utf-8"))
scene["resolution"] = {"x": preset["width"], "y": preset["height"]}
for source in scene.get("sources", []):
    if source.get("name") != "DAAK M3 Ekran":
        continue
    for item in source.get("settings", {}).get("items", []):
        item["scale_ref"] = {
            "x": float(preset["width"]),
            "y": float(preset["height"]),
        }
        item["bounds"] = {
            "x": float(preset["width"]),
            "y": float(preset["height"]),
        }

def atomic_write(path: Path, value: str) -> None:
    fd, temporary = tempfile.mkstemp(prefix=path.name + ".", suffix=".tmp", dir=path.parent)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            handle.write(value)
        os.chmod(temporary, path.stat().st_mode)
        os.replace(temporary, path)
    except Exception:
        try:
            os.unlink(temporary)
        except OSError:
            pass
        raise

atomic_write(profile_path, profile)
atomic_write(scene_path, json.dumps(scene, ensure_ascii=False, indent=4) + "\n")
PY
}

set_quality() {
  local requested="${1:-}" selected temporary
  case "$requested" in
    1080|1080p60) selected=1080p60 ;;
    1440|1440p60) selected=1440p60 ;;
    *) print -u2 -- "quality must be 1080p60 or 1440p60"; return 64 ;;
  esac
  running_pid >/dev/null 2>&1 && {
    print -u2 -- "stop the broadcast before changing quality"
    return 1
  }
  apply_direct_quality "$selected"
  /bin/mkdir -p "$ROOT"
  temporary="$QUALITY_FILE.$$"
  print -r -- "$selected" > "$temporary"
  /bin/mv "$temporary" "$QUALITY_FILE"
  write_state stopped "$(route)" "Yayın kalitesi $selected olarak ayarlandı."
  print -r -- "{\"quality\":\"$selected\"}"
}

ssh_host() {
  # Control traffic stays on the already-trusted Tailnet SSH alias. Media uses
  # Thunderbolt when available, so a stale direct-link SSH host key can never
  # block or weaken the broadcast control path.
  print -r -- mya-l11-tail
}

running_pid() {
  [[ -f "$PID_FILE" ]] || return 1
  local pid
  pid="$(<"$PID_FILE")"
  [[ "$pid" == <-> ]] || return 1
  /bin/kill -0 "$pid" 2>/dev/null || return 1
  /bin/ps -p "$pid" -o command= | /usr/bin/grep -F -- "--collection DAAK M3 Sender" >/dev/null
  print -r -- "$pid"
}

sender_state() {
  local pid
  pid="$(running_pid 2>/dev/null)" || { print -r -- stopped; return; }
  if sender_connected "$pid"; then
    print -r -- streaming
  else
    print -r -- idle
  fi
}

relay_pid() {
  [[ -f "$RELAY_PID_FILE" ]] || return 1
  local pid
  pid="$(<"$RELAY_PID_FILE")"
  [[ "$pid" == <-> ]] || return 1
  /bin/kill -0 "$pid" 2>/dev/null || return 1
  /bin/ps -p "$pid" -o command= | /usr/bin/grep -F -- "$RELAY" >/dev/null
  print -r -- "$pid"
}

sender_connected() {
  local obs_pid="$1"
  relay_pid >/dev/null 2>&1 && return 0
  # SRT uses a connected UDP socket, but macOS lsof reports it as a wildcard
  # local endpoint. OBS has no other UDP output in this dedicated profile.
  /usr/sbin/lsof -nP -a -p "$obs_pid" -iUDP 2>/dev/null | \
    /usr/bin/grep -F -- ' UDP ' >/dev/null
}

start_relay() {
  local selected="$1" host="$DIRECT_HOST" latency=80 pid
  [[ "$selected" == tailscale ]] && { host="$TAIL_HOST"; latency=180; }
  [[ -x "$RELAY" ]] || return 1
  /bin/launchctl remove app.daak.broadcast-relay >/dev/null 2>&1 || true
  /bin/mkdir -p "$ROOT/logs"
  /bin/launchctl submit -l app.daak.broadcast-relay -- "$RELAY" "$host" 9001 "$latency"
  pid=""
  for _ in {1..20}; do
    pid="$(/usr/bin/pgrep -n -f -- "$RELAY $host 9001 $latency" 2>/dev/null || true)"
    [[ "$pid" == <-> ]] && break
    /bin/sleep 0.1
  done
  [[ "$pid" == <-> ]] || return 1
  print -r -- "$pid" > "$RELAY_PID_FILE"
}

write_state() {
  local state="$1" selected="$2" message="$3"
  /bin/mkdir -p "$ROOT"
  /usr/bin/python3 - "$STATE_FILE" "$state" "$selected" "$message" <<'PY'
import json, os, sys, tempfile, time
path, state, route, message = sys.argv[1:]
payload = {"schema": 1, "state": state, "route": route, "message": message, "updatedAt": time.time()}
directory = os.path.dirname(path)
fd, tmp = tempfile.mkstemp(prefix="state.", suffix=".tmp", dir=directory)
with os.fdopen(fd, "w", encoding="utf-8") as handle:
    json.dump(payload, handle, ensure_ascii=False, separators=(",", ":"))
    handle.write("\n")
os.replace(tmp, path)
PY
}

status() {
  local selected sender receiver="unknown" quality effective
  selected="$(route)"
  quality="$(quality_selection)"
  effective="$quality"
  [[ "$selected" == tailscale ]] && effective=1080p30
  sender="$(sender_state)"
  if [[ "$selected" != offline ]]; then
    receiver="$(/usr/bin/ssh -o BatchMode=yes -o ConnectTimeout=3 "$(ssh_host "$selected")" \
      "$RECEIVER_COMMAND status" 2>/dev/null || print -r -- '{"state":"unknown"}')"
  else
    receiver='{"state":"offline"}'
  fi
  /usr/bin/python3 - "$selected" "$sender" "$receiver" "$quality" "$effective" <<'PY'
import json, sys, time
route, sender, receiver_raw, quality, effective = sys.argv[1:]
try:
    receiver = json.loads(receiver_raw).get("state", "unknown")
except Exception:
    receiver = "unknown"
print(json.dumps({
    "schema": 1,
    "route": route,
    "sender": sender,
    "receiver": receiver,
    "ready": route != "offline" and receiver in {"listening", "receiving"},
    "streaming": sender == "streaming" and receiver in {"listening", "receiving"},
    "quality": quality,
    "effectiveQuality": effective,
    "updatedAt": time.time()
}, separators=(",", ":")))
PY
}

start_split() {
  local selected="$1" remote profile pid="" quality effective
  remote="$(ssh_host "$selected")"
  quality="$(quality_selection)"
  effective="$quality"
  profile="DAAK Sender Thunderbolt"
  if [[ "$selected" == tailscale ]]; then
    profile="DAAK Sender Tailscale"
    effective=1080p30
  else
    apply_direct_quality "$quality"
  fi
  /usr/bin/ssh -o BatchMode=yes -o ConnectTimeout=5 "$remote" \
    "$RECEIVER_COMMAND start $effective" >/dev/null
  if [[ "$selected" == tailscale ]]; then
    start_relay "$selected"
  else
    /bin/launchctl remove app.daak.broadcast-relay >/dev/null 2>&1 || true
    /bin/rm -f "$RELAY_PID_FILE"
  fi
  /bin/sleep 2
  if pid="$(running_pid 2>/dev/null)"; then
    if [[ "$(sender_state)" == streaming ]]; then
      print -r -- "{\"state\":\"streaming\",\"route\":\"$selected\"}"
      return
    fi
    /bin/kill -TERM "$pid"
    for _ in {1..20}; do
      /bin/kill -0 "$pid" 2>/dev/null || break
      /bin/sleep 0.25
    done
    /bin/rm -f "$PID_FILE"
  fi
  /bin/mkdir -p "$ROOT/logs"
  /usr/bin/open -na /Applications/OBS.app --args --multi --disable-updater \
    --only-bundled-plugins --profile "$profile" --collection "DAAK M3 Sender" \
    --scene "DAAK M3 Ekran" --startrecording
  pid=""
  for _ in {1..30}; do
    pid="$(/usr/bin/pgrep -n -f -- '--collection DAAK M3 Sender' 2>/dev/null || true)"
    [[ "$pid" == <-> ]] && break
    /bin/sleep 0.25
  done
  [[ "$pid" == <-> ]] || return 1
  print -r -- "$pid" > "$PID_FILE"
  for _ in {1..40}; do
    [[ "$(sender_state)" == streaming ]] && break
    /bin/sleep 0.25
  done
  running_pid >/dev/null
  if [[ "$(sender_state)" == streaming ]]; then
    write_state streaming "$selected" "Intel yayın yolu başlatıldı."
    print -r -- "{\"state\":\"streaming\",\"route\":\"$selected\"}"
  else
    write_state idle "$selected" "M3 OBS açıldı fakat ara akış başlamadı."
    print -r -- "{\"state\":\"idle\",\"route\":\"$selected\"}"
    return 1
  fi
}

stop_all() {
  local pid selected
  if pid="$(running_pid 2>/dev/null)"; then
    /bin/kill -TERM "$pid"
    for _ in {1..20}; do
      /bin/kill -0 "$pid" 2>/dev/null || break
      /bin/sleep 0.25
    done
  fi
  /bin/rm -f "$PID_FILE"
  if pid="$(relay_pid 2>/dev/null)"; then
    /bin/kill -TERM "$pid"
  fi
  /bin/launchctl remove app.daak.broadcast-relay >/dev/null 2>&1 || true
  /bin/rm -f "$RELAY_PID_FILE"
  selected="$(route)"
  if [[ "$selected" != offline ]]; then
    /usr/bin/ssh -o BatchMode=yes -o ConnectTimeout=4 "$(ssh_host "$selected")" \
      "$RECEIVER_COMMAND stop" >/dev/null 2>&1 || true
  fi
  write_state stopped "$selected" "DAAK yayın süreçleri durduruldu."
  print -r -- "{\"state\":\"stopped\",\"route\":\"$selected\"}"
}

start_local() {
  /usr/bin/open -a /Applications/OBS.app
  write_state local offline "Intel erişilemiyor; yerel OBS açıldı."
  print -r -- '{"state":"local","route":"offline"}'
}

case "${1:-status}" in
  start)
    selected="$(route)"
    [[ "$selected" == offline ]] && start_local || start_split "$selected"
    ;;
  stop) stop_all ;;
  local) start_local ;;
  status) status ;;
  quality)
    if (( $# >= 2 )); then
      set_quality "$2"
    else
      print -r -- "{\"quality\":\"$(quality_selection)\"}"
    fi
    ;;
  *) print -u2 -- "usage: $0 {start|stop|local|status|quality [1080p60|1440p60]}"; exit 64 ;;
esac
