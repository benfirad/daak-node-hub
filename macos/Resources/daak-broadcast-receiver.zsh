#!/bin/zsh
set -euo pipefail

ROOT="$HOME/Library/Application Support/DAAK/Broadcast"
BRIDGE="$ROOT/bin/daak-srt-listener"
FFMPEG="$ROOT/bin/ffmpeg"
FIFO="$ROOT/media.ts"
BRIDGE_PID_FILE="$ROOT/srt-listener.pid"
FFMPEG_PID_FILE="$ROOT/intel-ffmpeg.pid"
RECORD_DIR="$HOME/Movies/DAAK Yayın"
LOG="$ROOT/logs/intel-headless-receiver.log"
QUALITY_FILE="$ROOT/quality-profile"

process_pid() {
  local file="$1" marker="$2" pid
  [[ -f "$file" ]] || return 1
  pid="$(<"$file")"
  [[ "$pid" == <-> ]] || return 1
  /bin/kill -0 "$pid" 2>/dev/null || return 1
  /bin/ps -p "$pid" -o command= | /usr/bin/grep -F -- "$marker" >/dev/null
  print -r -- "$pid"
}

receiver_state() {
  local pid
  pid="$(process_pid "$BRIDGE_PID_FILE" "daak-srt-listener" 2>/dev/null)" || {
    print -r -- stopped
    return
  }
  if /usr/sbin/lsof -nP -a -p "$pid" -iUDP:9001 2>/dev/null | /usr/bin/grep -q UDP; then
    local latest modified now
    latest="$(/bin/ls -t "$RECORD_DIR"/*.mkv 2>/dev/null | /usr/bin/head -1 || true)"
    if [[ -n "$latest" ]]; then
      modified="$(/usr/bin/stat -f %m "$latest" 2>/dev/null || print 0)"
      now="$(/bin/date +%s)"
      if (( now - modified <= 6 )); then
        print -r -- receiving
        return
      fi
    fi
    print -r -- listening
  else
    print -r -- idle
  fi
}

start_receiver() {
  local tier="${1:-1440p60}" state bridge_pid ffmpeg_pid bitrate maxrate bufsize
  case "$tier" in
    1080p60)
      bitrate=30000k
      maxrate=40000k
      bufsize=60000k
      ;;
    1440p60)
      bitrate=50000k
      maxrate=60000k
      bufsize=100000k
      ;;
    1080p30)
      bitrate=8000k
      maxrate=10000k
      bufsize=16000k
      ;;
    *)
      print -r -- '{"state":"error","message":"quality must be 1080p60, 1440p60, or 1080p30"}'
      return 64
      ;;
  esac
  state="$(receiver_state)"
  if [[ "$state" != stopped ]]; then
    if [[ "$state" == listening || "$state" == receiving ]] && \
       [[ -f "$QUALITY_FILE" && "$(<"$QUALITY_FILE")" == "$tier" ]]; then
      print -r -- "{\"state\":\"$state\"}"
      return
    fi
    stop_receiver >/dev/null
  fi
  [[ -x "$BRIDGE" && -x "$FFMPEG" ]] || {
    print -r -- '{"state":"error","message":"headless receiver missing"}'
    return 1
  }
  /bin/mkdir -p "$ROOT/logs" "$RECORD_DIR"
  [[ -p "$FIFO" ]] || /usr/bin/mkfifo "$FIFO"

  /usr/bin/nohup /bin/zsh -c '
    exec "$1" -hide_banner -nostdin -loglevel warning \
      -fflags +genpts+discardcorrupt -thread_queue_size 8192 -f mpegts -i "$2" \
      -map 0:v:0 -map "0:a?" -c:v h264_videotoolbox -profile:v high \
      -b:v "$4" -maxrate "$5" -bufsize "$6" -pix_fmt nv12 \
      -realtime 1 \
      -c:a aac -b:a 192k -ar 48000 \
      -f segment -segment_format matroska -segment_time 3600 \
      -reset_timestamps 1 -strftime 1 "$3/DAAK-%Y%m%d-%H%M%S.mkv"
  ' _ "$FFMPEG" "$FIFO" "$RECORD_DIR" "$bitrate" "$maxrate" "$bufsize" >> "$LOG" 2>&1 &
  ffmpeg_pid=$!
  print -r -- "$ffmpeg_pid" > "$FFMPEG_PID_FILE"

  /usr/bin/nohup /bin/zsh -c 'exec "$1" 9001 80 > "$2"' \
    _ "$BRIDGE" "$FIFO" 2>> "$LOG" &
  bridge_pid=$!
  print -r -- "$bridge_pid" > "$BRIDGE_PID_FILE"

  for _ in {1..30}; do
    [[ "$(receiver_state)" == listening ]] && {
      print -r -- "$tier" > "$QUALITY_FILE"
      print -r -- '{"state":"listening"}'
      return
    }
    /bin/sleep 0.2
  done
  print -r -- '{"state":"error","message":"SRT listener start failed"}'
  return 1
}

stop_receiver() {
  local pid
  if pid="$(process_pid "$BRIDGE_PID_FILE" "daak-srt-listener" 2>/dev/null)"; then
    /bin/kill -TERM "$pid"
  fi
  if pid="$(process_pid "$FFMPEG_PID_FILE" "$FIFO" 2>/dev/null)"; then
    /bin/kill -TERM "$pid"
  fi
  /bin/rm -f "$BRIDGE_PID_FILE" "$FFMPEG_PID_FILE"
  print -r -- '{"state":"stopped"}'
}

case "${1:-status}" in
  start) start_receiver "${2:-1440p60}" ;;
  stop) stop_receiver ;;
  status)
    state="$(receiver_state)"
    print -r -- "{\"state\":\"$state\"}"
    ;;
  *) print -u2 -- "usage: $0 {start [1080p60|1440p60|1080p30]|stop|status}"; exit 64 ;;
esac
