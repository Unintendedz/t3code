#!/usr/bin/env bash
# Launch this fork's Electron desktop client against its own T3 home (~/.t3-private).
# Defaults to remote-only mode on first run so it pairs with the background launchd
# server (scripts/fork-serve.sh) without contending for server-owner.sqlite.
#   scripts/fork-desktop.sh [start|foreground|build|install-app|uninstall-app|pair|log]
set -euo pipefail

export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:${PATH:-/usr/bin:/bin:/usr/sbin:/sbin}"

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
desktop_dir="${repo_root}/apps/desktop"
t3_home="${T3CODE_HOME:-$HOME/.t3-private}"
port="${T3CODE_PORT:-3780}"
log_file="${t3_home}/fork-desktop.log"
app_bundle="${T3CODE_FORK_APP_BUNDLE:-/Applications/T3 Code (Private).app}"

tailscale_socket="${T3CODE_TAILSCALE_SOCKET:-}"
if [[ -z "${tailscale_socket}" && -S "$HOME/.tailscaled/tailscaled.sock" ]]; then
  tailscale_socket="$HOME/.tailscaled/tailscaled.sock"
fi

node_bin="$(command -v node)"

ensure_settings() {
  local settings_file="${t3_home}/userdata/desktop-settings.json"
  mkdir -p "${t3_home}/userdata"
  if [[ ! -f "${settings_file}" ]]; then
    cat >"${settings_file}" <<'EOF'
{
  "localEnvironmentEnabled": false
}
EOF
  fi
}

build_desktop() {
  (
    cd "${desktop_dir}"
    "${node_bin}" scripts/build-browser-secret.mjs
    "${node_bin}" scripts/build-preview-annotation-css.mjs
    "${repo_root}/node_modules/.bin/vp" pack
    "${node_bin}" scripts/ensure-electron-runtime.mjs
  )
}

ensure_built() {
  if [[ ! -f "${desktop_dir}/dist-electron/main.cjs" ]]; then
    build_desktop
  fi
}

resolve_electron_command() {
  (
    cd "${desktop_dir}"
    unset VITE_DEV_SERVER_URL
    "${node_bin}" --input-type=module -e '
      import { resolveElectronLaunchCommand } from "./scripts/electron-launcher.mjs";
      const cmd = resolveElectronLaunchCommand(["dist-electron/main.cjs"]);
      process.stdout.write([cmd.electronPath, ...cmd.args, ""].join("\0"));
    '
  )
}

launch_desktop() {
  local mode="${1:-background}"
  ensure_settings
  ensure_built

  local -a cmd=()
  local item=""
  while IFS= read -r -d '' item; do
    cmd+=("${item}")
  done < <(resolve_electron_command)

  if [[ ${#cmd[@]} -eq 0 ]]; then
    echo "Failed to resolve Electron launch command." >&2
    exit 1
  fi

  mkdir -p "${t3_home}"
  export T3CODE_HOME="${t3_home}"
  export T3CODE_PORT="${port}"
  export T3CODE_DISABLE_AUTO_UPDATE=true
  if [[ -n "${tailscale_socket}" ]]; then
    export T3CODE_TAILSCALE_SOCKET="${tailscale_socket}"
  fi
  unset ELECTRON_RUN_AS_NODE
  unset VITE_DEV_SERVER_URL

  if [[ "${mode}" == "foreground" ]]; then
    cd "${desktop_dir}"
    exec "${cmd[@]}"
  fi

  (
    cd "${desktop_dir}"
    nohup "${cmd[@]}" </dev/null >>"${log_file}" 2>&1 &
  )
  echo "Launched T3 Code (Private) desktop client (T3CODE_HOME=${t3_home}). Log: ${log_file}"
}

install_app() {
  ensure_built
  # Populate apps/desktop/.electron-runtime (including icon.icns) before copying the icon.
  resolve_electron_command >/dev/null

  local icon_src="${desktop_dir}/.electron-runtime/icon-prod.icns"
  local contents_dir="${app_bundle}/Contents"
  local macos_dir="${contents_dir}/MacOS"
  local resources_dir="${contents_dir}/Resources"

  rm -rf "${app_bundle}"
  mkdir -p "${macos_dir}" "${resources_dir}"

  if [[ -f "${icon_src}" ]]; then
    cp "${icon_src}" "${resources_dir}/icon.icns"
  fi

  cat >"${contents_dir}/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key><string>en</string>
  <key>CFBundleDisplayName</key><string>T3 Code (Private)</string>
  <key>CFBundleExecutable</key><string>launch</string>
  <key>CFBundleIconFile</key><string>icon.icns</string>
  <key>CFBundleIdentifier</key><string>dev.t3code.fork.launcher</string>
  <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
  <key>CFBundleName</key><string>T3 Code (Private)</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
</dict>
</plist>
EOF

  cat >"${macos_dir}/launch" <<EOF
#!/usr/bin/env bash
set -euo pipefail
exec "${repo_root}/scripts/fork-desktop.sh" start
EOF
  chmod +x "${macos_dir}/launch"

  local lsregister="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
  if [[ -x "${lsregister}" ]]; then
    "${lsregister}" -f "${app_bundle}" >/dev/null 2>&1 || true
  fi
  echo "Installed launcher app at ${app_bundle}"
}

uninstall_app() {
  rm -rf "${app_bundle}"
  echo "Removed ${app_bundle}"
}

case "${1:-start}" in
  start) launch_desktop background ;;
  foreground) launch_desktop foreground ;;
  build) build_desktop ;;
  install-app) install_app ;;
  uninstall-app) uninstall_app ;;
  pair) exec "${repo_root}/scripts/fork-serve.sh" pair --local ;;
  log) tail -n 60 "${log_file}" ;;
  *)
    echo "Usage: $0 [start|foreground|build|install-app|uninstall-app|pair|log]" >&2
    exit 1
    ;;
esac
