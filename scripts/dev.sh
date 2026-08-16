#!/usr/bin/env bash
#
# Runs the app with auto hot-restart on save.
#
#   ./scripts/dev.sh            then open http://127.0.0.1:5173
#
# Why this exists: `flutter run` does not rebuild when a file changes — it waits
# for you to press `r` in its terminal. Edit a sprite, reload the browser, and
# you are served the *previous* bundle, which looks exactly like your edit
# having no effect. This keeps flutter's stdin open on a FIFO and writes a hot
# restart into it whenever anything under lib/ changes.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

PORT="${PORT:-5173}"
FIFO="/tmp/hog-pocket-dev.stdin"

cleanup() {
  [[ -n "${WATCH_PID:-}" ]] && kill "$WATCH_PID" 2>/dev/null || true
  [[ -n "${FLUTTER_PID:-}" ]] && kill "$FLUTTER_PID" 2>/dev/null || true
  exec 3>&- 2>/dev/null || true
  rm -f "$FIFO"
}
trap cleanup EXIT INT TERM

rm -f "$FIFO"
mkfifo "$FIFO"

flutter run -d web-server --web-port "$PORT" --web-hostname 127.0.0.1 <"$FIFO" &
FLUTTER_PID=$!

# Hold the write end open, or flutter sees EOF on stdin and gives up.
exec 3>"$FIFO"

fingerprint() {
  find lib -type f -name '*.dart' -exec stat -f '%m %N' {} + 2>/dev/null |
    sort | cksum
}

(
  last="$(fingerprint)"
  while true; do
    sleep 1
    now="$(fingerprint)"
    if [[ "$now" != "$last" ]]; then
      last="$now"
      printf 'R\n' >&3
      printf '\n  [dev.sh] lib/ changed — hot restarting\n'
    fi
  done
) &
WATCH_PID=$!

printf '\n  Hog Pocket dev server\n'
printf '    app      http://127.0.0.1:%s\n' "$PORT"
printf '    sprites  http://127.0.0.1:%s/#/dev/sprites\n' "$PORT"
printf '    editor   http://127.0.0.1:%s/#/dev/editor\n' "$PORT"
printf '  Saving any file under lib/ hot-restarts automatically.\n'
printf '  Ctrl-C to stop.\n\n'

wait "$FLUTTER_PID"
