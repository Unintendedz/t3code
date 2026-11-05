#!/usr/bin/env bash
# Run this fork's built server as a launchd user agent with its own data directory,
# reachable from this machine and over Tailscale HTTPS. It starts at login and restarts
# if it exits.
#   scripts/fork-serve.sh start|stop|restart|status|pair|log
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

label="dev.t3code.fork"
t3_home="${T3CODE_HOME:-$HOME/.t3-private}"
port="${T3CODE_PORT:-3780}"
log_file="${t3_home}/fork-server.log"
plist="$HOME/Library/LaunchAgents/${label}.plist"
domain="gui/$(id -u)"
mkdir -p "${t3_home}" "$(dirname "${plist}")"

write_plist() {
  cat >"${plist}" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>${label}</string>
  <key>ProgramArguments</key>
  <array>
    <string>$(command -v node)</string>
    <string>${PWD}/apps/server/dist/bin.mjs</string>
    <string>--port</string><string>${port}</string>
    <string>--no-browser</string>
    <string>--tailscale-serve</string>
  </array>
  <key>EnvironmentVariables</key>
  <dict>
    <key>T3CODE_HOME</key><string>${t3_home}</string>
    <key>T3CODE_AUTO_BOOTSTRAP_PROJECT_FROM_CWD</key><string>false</string>
  </dict>
  <key>WorkingDirectory</key><string>${HOME}</string>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>StandardOutPath</key><string>${log_file}</string>
  <key>StandardErrorPath</key><string>${log_file}</string>
</dict>
</plist>
EOF
}

loaded() { launchctl print "${domain}/${label}" >/dev/null 2>&1; }

unload() {
  loaded || return 0
  launchctl bootout "${domain}/${label}" || true
  # bootout returns before the job is gone, and bootstrap fails until it is.
  while loaded; do sleep 0.2; done
}

# pair finds the server through its runtime file, which appears a moment after launch.
wait_ready() {
  local runtime="${t3_home}/userdata/server-runtime.json"
  for _ in $(seq 1 150); do
    local pid
    pid="$(node -p "try { require('${runtime}').pid ?? '' } catch { '' }")"
    [[ -n "${pid}" ]] && kill -0 "${pid}" 2>/dev/null && return 0
    sleep 0.2
  done
  echo "${label} did not become ready within 30s. See: scripts/fork-serve.sh log" >&2
  exit 1
}

case "${1:-status}" in
  start)
    write_plist
    loaded || launchctl bootstrap "${domain}" "${plist}"
    wait_ready
    echo "Started ${label} on 127.0.0.1:${port}. Log: ${log_file}"
    ;;
  stop)
    unload
    echo "Stopped ${label}; it will not start at login until the next start."
    rm -f "${plist}"
    ;;
  restart)
    unload
    write_plist
    launchctl bootstrap "${domain}" "${plist}"
    wait_ready
    echo "Restarted ${label}."
    ;;
  status) launchctl print "${domain}/${label}" 2>/dev/null | sed -n '/^\tstate =/p;/^\tpid =/p' || echo "Not loaded." ;;
  pair)
    # One-time tokens expire; mint one right before pasting it.
    tailscale_flag=""
    command -v tailscale >/dev/null && tailscale_flag="--tailscale"
    node apps/server/dist/bin.mjs pair --base-dir "${t3_home}" --ttl 15m ${tailscale_flag}
    ;;
  log) tail -n 60 "${log_file}" ;;
  *)
    echo "Usage: $0 start|stop|restart|status|pair|log" >&2
    exit 1
    ;;
esac
