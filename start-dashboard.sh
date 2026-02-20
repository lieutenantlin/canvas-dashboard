#!/usr/bin/env bash

# ┌─────────────────────────────────────────┐
# │  CANVAS TERMINAL DASHBOARD — LAUNCHER   │
# └─────────────────────────────────────────┘

PORT=8080
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FILE="canvas-dashboard.html"
URL="http://localhost:$PORT/$FILE"
PIDFILE="/tmp/canvas-dashboard.pid"
LOGFILE="/tmp/canvas-dashboard.log"

# ── If called with 'stop', kill the server ──
if [[ "$1" == "stop" ]]; then
  if [[ -f "$PIDFILE" ]]; then
    PID=$(cat "$PIDFILE")
    echo "[ >> ] Stopping Canvas Dashboard (PID $PID)..."
    kill "$PID" 2>/dev/null
    rm -f "$PIDFILE"
    echo "[ OK ] Stopped."
  else
    echo "[WARN] No running dashboard found."
  fi
  exit 0
fi

# ── Re-exec in background if not already ────
if [[ "$1" != "--background" ]]; then
  nohup "$0" --background &>"$LOGFILE" &
  sleep 1
  echo "[ OK ] Canvas Dashboard launched in background"
  echo "[ OK ] Browser opening at $URL"
  echo "[ >> ] To stop it later, run: ./start-dashboard.sh stop"
  echo "[ >> ] Logs: $LOGFILE"
  exit 0
fi

# ── Everything below runs in the background ──

# ── Find a Python 3 binary ──────────────────
if command -v python3 &>/dev/null; then
  PYTHON=python3
elif command -v python &>/dev/null && python --version 2>&1 | grep -q "Python 3"; then
  PYTHON=python
else
  echo "[FAIL] Python 3 not found. Install it with: sudo pacman -S python"
  exit 1
fi

# ── Check the HTML file exists ──────────────
if [[ ! -f "$DIR/$FILE" ]]; then
  echo "[FAIL] $FILE not found in $DIR"
  exit 1
fi

# ── Kill anything already on the port ───────
if lsof -ti tcp:$PORT &>/dev/null; then
  echo "[ >> ] Port $PORT in use — killing existing process..."
  lsof -ti tcp:$PORT | xargs kill -9
  sleep 0.5
fi

# ── Start the server ────────────────────────
echo "[ >> ] Starting server at $URL"
cd "$DIR"
$PYTHON -m http.server $PORT --bind 127.0.0.1 &>/dev/null &
SERVER_PID=$!
echo $SERVER_PID > "$PIDFILE"

# ── Wait for server to be ready ─────────────
for i in {1..10}; do
  if curl -s "http://localhost:$PORT" &>/dev/null; then
    break
  fi
  sleep 0.3
done

# ── Open Chromium with web security disabled ─
echo "[ >> ] Opening $URL in Chromium (CORS disabled)"

CHROMIUM_FLAGS="--disable-web-security --user-data-dir=/tmp/canvas-dash-profile"

if command -v chromium &>/dev/null; then
  chromium $CHROMIUM_FLAGS "$URL" &>/dev/null &
elif command -v chromium-browser &>/dev/null; then
  chromium-browser $CHROMIUM_FLAGS "$URL" &>/dev/null &
elif command -v google-chrome-stable &>/dev/null; then
  google-chrome-stable $CHROMIUM_FLAGS "$URL" &>/dev/null &
elif command -v google-chrome &>/dev/null; then
  google-chrome $CHROMIUM_FLAGS "$URL" &>/dev/null &
else
  echo "[FAIL] Chromium/Chrome not found. Install with: sudo pacman -S chromium"
  kill $SERVER_PID
  rm -f "$PIDFILE"
  exit 1
fi

echo "[ OK ] Dashboard running in background."

# ── Keep server alive ────────────────────────
wait $SERVER_PID
rm -f "$PIDFILE"
