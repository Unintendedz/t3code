#!/usr/bin/env bash
# One-way copy of the official T3 Code data into this fork's T3 home.
# Projects, threads, attachments, settings, keybindings, themes, and provider credentials
# come across. T3 Connect and T3 account state, telemetry ids, auth sessions, logs, and
# caches do not. The fork's previous userdata is kept as userdata.before-migrate-<time>.
# Quit the official app first. On start the fork resumes turns that were running when the
# official server stopped, as the official app would after a restart; with both servers up,
# the same turn would run twice, so this refuses while the official server is alive.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

source_dir="${T3_OFFICIAL_HOME:-$HOME/.t3}/userdata"
fork_home="${T3CODE_HOME:-$HOME/.t3-private}"
target_dir="${fork_home}/userdata"
backup_dir="${fork_home}/userdata.before-migrate-$(date +%Y%m%d-%H%M%S)"

[[ -f "${source_dir}/statev2.sqlite" ]] || {
  echo "No official database at ${source_dir}/statev2.sqlite." >&2
  exit 1
}

official_pid="$(node -p "try { require('${source_dir}/server-runtime.json').pid ?? '' } catch { '' }")"
if [[ -n "${official_pid}" ]] && kill -0 "${official_pid}" 2>/dev/null; then
  echo "The official T3 Code server is running (pid ${official_pid}). Quit the official app first." >&2
  exit 1
fi

# Assemble the copy beside the target so a failure leaves the fork's data untouched.
staging_dir="${fork_home}/userdata.migrating"
rm -rf "${staging_dir}"
mkdir -p "${staging_dir}/secrets"
chmod 700 "${staging_dir}" "${staging_dir}/secrets"

# immutable=1 reads without creating -shm/-wal or taking locks, which a cleanly closed WAL
# database needs for any other read-only open; safe because the official server is stopped.
sqlite3 "file:${source_dir}/statev2.sqlite?immutable=1" ".backup '${staging_dir}/statev2.sqlite'"
# Paired clients start over: the fork has its own address, and these include T3 Connect clients.
sqlite3 "${staging_dir}/statev2.sqlite" "DELETE FROM auth_sessions; DELETE FROM auth_pairing_links;"

for entry in attachments themes settings.json client-settings.json keybindings.json \
  keybindings-migrations compacted-at environment-id; do
  if [[ -e "${source_dir}/${entry}" ]]; then
    cp -R "${source_dir}/${entry}" "${staging_dir}/"
  fi
done

# Server keys and provider credentials only. Not cloud-* (T3 Connect) or dpop-proof-* (replay markers).
for secret in "${source_dir}"/secrets/*.bin; do
  case "$(basename "${secret}")" in
    server-signing-key.bin | asset-access-signing-key.bin | mcp-oauth-signing-key.bin | \
      secret-request-salt.bin | provider-auth-*.bin)
      cp "${secret}" "${staging_dir}/secrets/"
      ;;
  esac
done
chmod 600 "${staging_dir}"/secrets/*

scripts/fork-serve.sh stop
if [[ -d "${target_dir}" ]]; then
  mv "${target_dir}" "${backup_dir}"
  echo "Previous fork data: ${backup_dir}"
fi
mv "${staging_dir}" "${target_dir}"

scripts/fork-serve.sh start
echo "Migrated. Pair your browser again: scripts/fork-serve.sh pair"
