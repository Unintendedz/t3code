#!/usr/bin/env bash
# Rebase the privacy branch onto upstream, then reinstall, test the patch, and rebuild.
#   scripts/fork-sync.sh          newest upstream stable release (GitHub "latest" release)
#   scripts/fork-sync.sh main     upstream/main (nightly train)
#   scripts/fork-sync.sh v0.1.8   a specific upstream tag
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "Commit or stash local changes first." >&2
  exit 1
fi

git fetch upstream --tags --prune
case "${1:-latest}" in
  latest) target="$(gh release view --repo pingdotgg/t3code --json tagName --jq .tagName)" ;;
  main) target="upstream/main" ;;
  *) target="$1" ;;
esac

echo "Rebasing privacy onto ${target}"
git rebase "${target}" privacy

npx -y "$(node -p "require('./package.json').packageManager")" install
(cd packages/shared && ../../node_modules/.bin/vp test run src/otelEnvironment.test.ts)
node_modules/.bin/vp run --filter t3 build

echo "Synced to ${target}. Restart the server: scripts/fork-serve.sh restart"
