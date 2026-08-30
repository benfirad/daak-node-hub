#!/bin/zsh
set -euo pipefail

ROOT="$HOME/Library/Application Support/DAAK/Broadcast"
PID_FILE="$ROOT/m3-obs.pid"
RELAY_PID_FILE="$ROOT/m3-srt-relay.pid"
STATE_FILE="$ROOT/state.json"
QUALITY_FILE="$ROOT/quality-profile"
LAYOUT_FILE="$ROOT/layout-profile"
VERTICAL_LAYOUT_FILE="$ROOT/vertical-layout-profile"
CAPTURE_MODE_FILE="$ROOT/capture-mode-profile"
CAMERA_CONFIG="$ROOT/camera-sources.conf"
CAMERA_SCRIPT="$ROOT/scripts/create_m3_scene.lua"
OBS_PROFILE="$HOME/Library/Application Support/obs-studio/basic/profiles/DAAK Sender Thunderbolt/basic.ini"
OBS_SCENE="$HOME/Library/Application Support/obs-studio/basic/scenes/DAAK M3 Sender.json"
OBS_PLUGINS="$HOME/Library/Application Support/obs-studio/plugins"
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

sync_camera_script() {
  local source="${0:A:h}/create_m3_scene.lua"
  [[ -f "$source" ]] || return 0
  /bin/mkdir -p "${CAMERA_SCRIPT:h}"
  if [[ ! -f "$CAMERA_SCRIPT" ]] || ! /usr/bin/cmp -s "$source" "$CAMERA_SCRIPT"; then
    /bin/cp "$source" "$CAMERA_SCRIPT"
  fi
}

studio_ready() {
  [[ -d "$OBS_PLUGINS/vertical-canvas.plugin" && -d "$OBS_PLUGINS/aitum-multistream.plugin" ]]
}

camera_ready() {
  [[ -f "$CAMERA_CONFIG" && -f "$CAMERA_SCRIPT" ]] || return 1
  /usr/bin/grep -Eq '^mac_camera_id=.+' "$CAMERA_CONFIG" && \
    /usr/bin/grep -Eq '^phone_camera_id=.+' "$CAMERA_CONFIG"
}

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

layout_selection() {
  local selected="studio"
  [[ -f "$LAYOUT_FILE" ]] && selected="$(<"$LAYOUT_FILE")"
  case "$selected" in
    screen|studio|phone|mac) print -r -- "$selected" ;;
    *) print -r -- studio ;;
  esac
}

layout_scene() {
  case "${1:-$(layout_selection)}" in
    screen) print -r -- "DAAK M3 Ekran" ;;
    phone) print -r -- "DAAK Telefon Tam" ;;
    mac) print -r -- "DAAK M3 Kamera Tam" ;;
    *) print -r -- "DAAK Ekran + Kameralar" ;;
  esac
}

vertical_layout_selection() {
  local selected="screen-phone"
  [[ -f "$VERTICAL_LAYOUT_FILE" ]] && selected="$(<"$VERTICAL_LAYOUT_FILE")"
  case "$selected" in
    screen-phone|screen-mac|triple) print -r -- "$selected" ;;
    *) print -r -- screen-phone ;;
  esac
}

capture_mode_selection() {
  local selected="window"
  [[ -f "$CAPTURE_MODE_FILE" ]] && selected="$(<"$CAPTURE_MODE_FILE")"
  case "$selected" in
    window|display) print -r -- "$selected" ;;
    *) print -r -- window ;;
  esac
}

any_obs_running() {
  /usr/bin/pgrep -x OBS >/dev/null 2>&1
}

set_vertical_layout() {
  local requested="${1:-}" temporary
  case "$requested" in
    screen-phone|screen-mac|triple) ;;
    *) print -u2 -- "vertical layout must be screen-phone, screen-mac, or triple"; return 64 ;;
  esac
  any_obs_running && {
    print -u2 -- "OBS'yi kapatıp dikey düzeni tekrar seç"
    return 1
  }
  /bin/mkdir -p "$ROOT"
  temporary="$VERTICAL_LAYOUT_FILE.$$"
  print -r -- "$requested" > "$temporary"
  /bin/mv "$temporary" "$VERTICAL_LAYOUT_FILE"
  write_state stopped "$(route)" "Dikey yayın düzeni $requested olarak ayarlandı."
  print -r -- "{\"verticalLayout\":\"$requested\"}"
}

set_capture_mode() {
  local requested="${1:-}" temporary
  case "$requested" in
    window|display) ;;
    *) print -u2 -- "capture mode must be window or display"; return 64 ;;
  esac
  any_obs_running && {
    print -u2 -- "OBS'yi kapatıp yakalama modunu tekrar seç"
    return 1
  }
  /bin/mkdir -p "$ROOT"
  temporary="$CAPTURE_MODE_FILE.$$"
  print -r -- "$requested" > "$temporary"
  /bin/mv "$temporary" "$CAPTURE_MODE_FILE"
  if [[ "$requested" == display ]]; then
    apply_capture_mode
    write_state stopped "$(route)" "Tüm ekran yakalama modu seçildi; mahremiyet uyarısı etkin."
  else
    apply_capture_mode 2>/dev/null || true
    write_state stopped "$(route)" "Güvenli tek pencere yakalama modu seçildi."
  fi
  print -r -- "{\"captureMode\":\"$requested\"}"
}

set_capture_window() {
  local window_id="${1:-}" owner="${2:-}" title="${3:-}"
  any_obs_running && {
    print -u2 -- "OBS'yi kapatıp güvenli yayın penceresini tekrar seç"
    return 1
  }
  /bin/mkdir -p "$ROOT"
  /usr/bin/python3 - "$CAMERA_CONFIG" "$window_id" "$owner" "$title" <<'PY'
import os
from pathlib import Path
import sys
import tempfile

path = Path(sys.argv[1])
try:
    window_id = int(sys.argv[2])
except ValueError:
    raise SystemExit("window id must be numeric")
owner = sys.argv[3].replace("\r", " ").replace("\n", " ").strip()
title = sys.argv[4].replace("\r", " ").replace("\n", " ").strip()
if not 0 < window_id <= 0xFFFFFFFF or not owner or not title:
    raise SystemExit("a visible named window must be selected")
if len(owner) > 200 or len(title) > 500:
    raise SystemExit("window label is too long")

values = {}
order = []
if path.is_file():
    for line in path.read_text(encoding="utf-8").splitlines():
        key, separator, value = line.partition("=")
        if separator and key and key not in values:
            values[key] = value
            order.append(key)
values.update({
    "capture_window_id": str(window_id),
    "capture_window_owner": owner,
    "capture_window_title": title,
})
for key in ("capture_window_id", "capture_window_owner", "capture_window_title"):
    if key not in order:
        order.append(key)

fd, temporary = tempfile.mkstemp(prefix=path.name + ".", suffix=".tmp", dir=path.parent)
try:
    with os.fdopen(fd, "w", encoding="utf-8") as handle:
        for key in order:
            handle.write(f"{key}={values[key]}\n")
    if path.exists():
        os.chmod(temporary, path.stat().st_mode)
    os.replace(temporary, path)
except Exception:
    try:
        os.unlink(temporary)
    except OSError:
        pass
    raise
PY
  apply_capture_mode
  write_state stopped "$(route)" "Güvenli pencere yakalama hedefi ayarlandı."
  print -r -- "{\"captureWindowID\":$window_id}"
}

clear_capture_window() {
  any_obs_running && {
    print -u2 -- "OBS'yi kapatıp güvenli yayın penceresini tekrar temizle"
    return 1
  }
  /usr/bin/python3 - "$CAMERA_CONFIG" <<'PY'
import os
from pathlib import Path
import sys
import tempfile

path = Path(sys.argv[1])
lines = []
if path.is_file():
    for line in path.read_text(encoding="utf-8").splitlines():
        if not line.startswith(("capture_window_id=", "capture_window_owner=", "capture_window_title=")):
            lines.append(line)
fd, temporary = tempfile.mkstemp(prefix=path.name + ".", suffix=".tmp", dir=path.parent)
try:
    with os.fdopen(fd, "w", encoding="utf-8") as handle:
        if lines:
            handle.write("\n".join(lines) + "\n")
    if path.exists():
        os.chmod(temporary, path.stat().st_mode)
    os.replace(temporary, path)
except Exception:
    try:
        os.unlink(temporary)
    except OSError:
        pass
    raise
PY
  apply_capture_mode 2>/dev/null || true
  write_state stopped "$(route)" "Güvenli yayın penceresi seçimi temizlendi."
  print -r -- '{"captureWindowID":null}'
}

apply_capture_mode() {
  /usr/bin/python3 - "$CAMERA_CONFIG" "$OBS_SCENE" "$(capture_mode_selection)" <<'PY'
import json
import os
from pathlib import Path
import sys
import tempfile

config_path, scene_path = map(Path, sys.argv[1:3])
mode = sys.argv[3]
values = {}
if config_path.is_file():
    for line in config_path.read_text(encoding="utf-8").splitlines():
        key, separator, value = line.partition("=")
        if separator:
            values[key] = value
try:
    window_id = int(values.get("capture_window_id", "0"))
except ValueError:
    window_id = 0
if not scene_path.is_file():
    raise SystemExit("OBS yayın sahnesi bulunamadı")

scene = json.loads(scene_path.read_text(encoding="utf-8"))
capture = next((source for source in scene.get("sources", []) if source.get("name") == "M3 Ekran ve Ses"), None)
if capture is None:
    raise SystemExit("OBS ekran kaynağı bulunamadı")
settings = capture.setdefault("settings", {})
if mode == "display":
    display_uuid = settings.get("display_uuid")
    if not display_uuid:
        scripts = scene.get("modules", {}).get("scripts-tool", [])
        if isinstance(scripts, dict):
            scripts = scripts.get("scripts", [])
        for script in scripts:
            candidate = script.get("settings", {}).get("display_uuid")
            if isinstance(candidate, str) and candidate:
                display_uuid = candidate
                break
    if not display_uuid:
        raise SystemExit("OBS tam ekran hedefi bulunamadı")
    settings.update({"type": 0, "display_uuid": display_uuid})
    settings.pop("window", None)
else:
    configured = window_id > 0 and values.get("capture_window_owner") and values.get("capture_window_title")
    settings.update({"type": 1, "window": window_id if configured else 0})
    settings.pop("display_uuid", None)
settings.update({
    "show_cursor": True,
    "hide_obs": True,
    "show_empty_names": False,
    "show_hidden_windows": False,
})

fd, temporary = tempfile.mkstemp(prefix=scene_path.name + ".", suffix=".tmp", dir=scene_path.parent)
try:
    with os.fdopen(fd, "w", encoding="utf-8") as handle:
        json.dump(scene, handle, ensure_ascii=False, indent=4)
        handle.write("\n")
    os.chmod(temporary, scene_path.stat().st_mode)
    os.replace(temporary, scene_path)
except Exception:
    try:
        os.unlink(temporary)
    except OSError:
        pass
    raise
PY
}

capture_ready() {
  /usr/bin/python3 - "$CAMERA_CONFIG" "$OBS_SCENE" "$(capture_mode_selection)" <<'PY'
import json
from pathlib import Path
import sys

config_path, scene_path = map(Path, sys.argv[1:3])
mode = sys.argv[3]
values = {}
try:
    for line in config_path.read_text(encoding="utf-8").splitlines():
        key, separator, value = line.partition("=")
        if separator:
            values[key] = value
    window_id = int(values.get("capture_window_id", "0"))
    scene = json.loads(scene_path.read_text(encoding="utf-8"))
    capture = next(source for source in scene.get("sources", []) if source.get("name") == "M3 Ekran ve Ses")
    settings = capture.get("settings", {})
except (OSError, ValueError, StopIteration, json.JSONDecodeError):
    raise SystemExit(1)
if mode == "display" and settings.get("type") == 0 and settings.get("display_uuid"):
    raise SystemExit(0)
if (mode == "window" and window_id > 0 and values.get("capture_window_owner")
        and values.get("capture_window_title") and settings.get("type") == 1
        and int(settings.get("window", 0)) > 0 and not settings.get("display_uuid")):
    raise SystemExit(0)
raise SystemExit(1)
PY
}

set_layout() {
  local requested="${1:-}" temporary
  case "$requested" in
    screen|studio|phone|mac) ;;
    *) print -u2 -- "layout must be screen, studio, phone, or mac"; return 64 ;;
  esac
  running_pid >/dev/null 2>&1 && {
    print -u2 -- "stop the broadcast before changing layout"
    return 1
  }
  /bin/mkdir -p "$ROOT"
  temporary="$LAYOUT_FILE.$$"
  print -r -- "$requested" > "$temporary"
  /bin/mv "$temporary" "$LAYOUT_FILE"
  write_state stopped "$(route)" "Yayın düzeni $(layout_scene "$requested") olarak ayarlandı."
  print -r -- "{\"layout\":\"$requested\"}"
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

terminate_obs_pid() {
  local pid="$1"
  [[ "$pid" == <-> ]] || return 0
  /bin/ps -p "$pid" -o command= | /usr/bin/grep -F -- "--collection DAAK M3 Sender" >/dev/null || return 0
  /bin/kill -TERM "$pid" 2>/dev/null || return 0
  for _ in {1..20}; do
    /bin/kill -0 "$pid" 2>/dev/null || return 0
    /bin/sleep 0.25
  done
  /bin/ps -p "$pid" -o command= | /usr/bin/grep -F -- "--collection DAAK M3 Sender" >/dev/null || return 0
  /bin/kill -KILL "$pid" 2>/dev/null || true
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
  local selected sender receiver="unknown" quality effective layout vertical capture_mode studio=false cameras=false privacy=false
  selected="$(route)"
  quality="$(quality_selection)"
  layout="$(layout_selection)"
  vertical="$(vertical_layout_selection)"
  capture_mode="$(capture_mode_selection)"
  effective="$quality"
  [[ "$selected" == tailscale ]] && effective=1080p30
  sender="$(sender_state)"
  studio_ready && studio=true
  camera_ready && cameras=true
  capture_ready && privacy=true
  if [[ "$selected" != offline ]]; then
    receiver="$(/usr/bin/ssh -o BatchMode=yes -o ConnectTimeout=3 "$(ssh_host "$selected")" \
      "$RECEIVER_COMMAND status" 2>/dev/null || print -r -- '{"state":"unknown"}')"
  else
    receiver='{"state":"offline"}'
  fi
  /usr/bin/python3 - "$selected" "$sender" "$receiver" "$quality" "$effective" "$layout" "$vertical" "$capture_mode" "$studio" "$cameras" "$privacy" "$CAMERA_CONFIG" <<'PY'
import json, sys, time
route, sender, receiver_raw, quality, effective, layout, vertical, capture_mode, studio, cameras, privacy, config_path = sys.argv[1:]
try:
    receiver = json.loads(receiver_raw).get("state", "unknown")
except Exception:
    receiver = "unknown"
window_id = None
window_owner = None
try:
    values = {}
    with open(config_path, encoding="utf-8") as handle:
        for line in handle:
            key, separator, value = line.rstrip("\n").partition("=")
            if separator:
                values[key] = value
    window_id = int(values.get("capture_window_id", "0")) or None
    window_owner = values.get("capture_window_owner") or None
except (OSError, ValueError):
    pass
print(json.dumps({
    "schema": 1,
    "route": route,
    "sender": sender,
    "receiver": receiver,
    "ready": route != "offline" and receiver in {"listening", "receiving"},
    "streaming": sender == "streaming" and receiver in {"listening", "receiving"},
    "quality": quality,
    "effectiveQuality": effective,
    "layout": layout,
    "verticalLayout": vertical,
    "captureMode": capture_mode,
    "studioReady": studio == "true",
    "cameraReady": cameras == "true",
    "privacyReady": privacy == "true",
    "captureWindowID": window_id,
    "captureWindowOwner": window_owner,
    "updatedAt": time.time()
}, separators=(",", ":")))
PY
}

start_split() {
  local selected="$1" remote profile pid="" quality effective layout
  remote="$(ssh_host "$selected")"
  quality="$(quality_selection)"
  layout="$(layout_selection)"
  effective="$quality"
  profile="DAAK Sender Thunderbolt"
  if [[ "$selected" == tailscale ]]; then
    profile="DAAK Sender Tailscale"
    effective=1080p30
  else
    apply_direct_quality "$quality"
  fi
  sync_camera_script
  if ! apply_capture_mode; then
    write_state blocked "$selected" "Seçilen ekran yakalama modu hazırlanamadı."
    return 1
  fi
  capture_ready || {
    if [[ "$(capture_mode_selection)" == display ]]; then
      write_state blocked "$selected" "Tüm ekran yakalama hedefi hazır değil."
      print -u2 -- "OBS tam ekran hedefi hazır değil."
    else
      write_state blocked "$selected" "Güvenli pencere seçilmeden yayın başlatılmadı."
      print -u2 -- "Önce DAAK Node'dan güvenli yayın penceresini seç."
    fi
    return 1
  }
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
    terminate_obs_pid "$pid"
    /bin/rm -f "$PID_FILE"
  fi
  /bin/mkdir -p "$ROOT/logs"
  /usr/bin/open -na /Applications/OBS.app --args --multi --disable-updater \
    --profile "$profile" --collection "DAAK M3 Sender" \
    --scene "$(layout_scene "$layout")" --startrecording
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
    terminate_obs_pid "$pid"
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
  sync_camera_script
  apply_capture_mode 2>/dev/null || true
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
  layout)
    if (( $# >= 2 )); then
      set_layout "$2"
    else
      print -r -- "{\"layout\":\"$(layout_selection)\"}"
    fi
    ;;
  vertical)
    if (( $# >= 2 )); then
      set_vertical_layout "$2"
    else
      print -r -- "{\"verticalLayout\":\"$(vertical_layout_selection)\"}"
    fi
    ;;
  capture)
    if (( $# >= 2 )); then
      set_capture_mode "$2"
    else
      print -r -- "{\"captureMode\":\"$(capture_mode_selection)\"}"
    fi
    ;;
  window)
    if (( $# == 2 )) && [[ "$2" == clear ]]; then
      clear_capture_window
    else
      (( $# == 4 )) || { print -u2 -- "window requires id, owner, and title"; exit 64; }
      set_capture_window "$2" "$3" "$4"
    fi
    ;;
  *) print -u2 -- "usage: $0 {start|stop|local|status|quality [1080p60|1440p60]|layout [screen|studio|phone|mac]|vertical [screen-phone|screen-mac|triple]|capture [window|display]|window ID OWNER TITLE|window clear}"; exit 64 ;;
esac
