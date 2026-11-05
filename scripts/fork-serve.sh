#!/usr/bin/env bash
# Run this fork's built server in the background with its own data directory,
# reachable from this machine and over Tailscale HTTPS.
#   scripts/fork-serve.sh start|stop|restart|status|pair
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

export T3CODE_HOME="${T3CODE_HOME:-$HOME/.t3-private}"
port="${T3CODE_PORT:-3780}"
pid_file="${T3CODE_HOME}/fork-server.pid"
log_file="${T3CODE_HOME}/fork-server.log"
mkdir -p "${T3CODE_HOME}"

running() { [[ -f "${pid_file}" ]] && kill -0 "$(cat "${pid_file}")" 2>/dev/null; }

start() {
  if running; then
    echo "Already running (pid $(cat "${pid_file}"))."
    return
  fi
  nohup node apps/server/dist/bin.mjs --port "${port}" --no-browser --tailscale-serve \
    >>"${log_file}" 2>&1 &
  echo $! >"${pid_file}"
  echo "Started pid $! on 127.0.0.1:${port}. Log: ${log_file}"
}

stop() {
  if running; then
    kill "$(cat "${pid_file}")"
    echo "Stopped pid $(cat "${pid_file}")."
  fi
  rm -f "${pid_file}"
}

case "${1:-status}" in
  start) start ;;
  stop) stop ;;
  restart) stop && sleep 1 && start ;;
  status) running && echo "Running (pid $(cat "${pid_file}")). Log: ${log_file}" || echo "Not running." ;;
  pair) node apps/server/dist/bin.mjs pair --base-dir "${T3CODE_HOME}" --tailscale ;;
  *) echo "Usage: $0 start|stop|restart|status|pair" >&2; exit 1 ;;
esac
