> [!NOTE]
> **Privacy Fork (`privacy` branch)** — Forked from [`pingdotgg/t3code`](https://github.com/pingdotgg/t3code). Below is a summary of what this branch changes and how to run it locally; the original upstream README follows.

## What's Changed in This Fork (`privacy`)

### Privacy & self-hosted defaults

- **Telemetry & relay tracing off by default**: `T3CODE_TELEMETRY_ENABLED` now defaults to `false` (both PostHog product analytics and OpenTelemetry relay tracing stay disabled unless explicitly set to `true`).
- **No default T3-hosted relay**: `.env.example` comments out `T3CODE_RELAY_URL=https://relay.t3.codes` by default.
- **Mobile OTA updates off by default**: Expo OTA updates in `apps/mobile/app.config.ts` are disabled unless `T3CODE_MOBILE_UPDATES_ENABLED=1` is set at build time.
- **Desktop auto-update disabled in launcher**: `scripts/fork-desktop.sh` launches Electron with `T3CODE_DISABLE_AUTO_UPDATE=true`.

### Custom Tailscale socket support

- `packages/tailscale` honors `T3CODE_TAILSCALE_SOCKET` (passed to `tailscale --socket=...`) so T3 Code works with a non-default `tailscaled` socket.
- `scripts/fork-serve.sh` bakes `T3CODE_TAILSCALE_SOCKET` into the `launchd` service when set; `scripts/fork-serve.sh pair` and `scripts/fork-desktop.sh` also auto-detect `$HOME/.tailscaled/tailscaled.sock` when unset.

### Fork management & macOS launch scripts

All fork scripts isolate state in `~/.t3-private` (`T3CODE_HOME`) on port `3780` (`T3CODE_PORT`), separate from an official `~/.t3` install:

- [`scripts/fork-serve.sh`](./scripts/fork-serve.sh) — Run the built server as a macOS `launchd` user agent (`--tailscale-serve`, auto-start on login, waits until ready on `start`/`restart`, disables `T3CODE_AUTO_BOOTSTRAP_PROJECT_FROM_CWD`). Subcommands: `start | stop | restart | status | pair [--local] | log`.
- [`scripts/fork-desktop.sh`](./scripts/fork-desktop.sh) — Build and launch the Electron desktop client in remote-only mode so it connects to the background server without contending for the database. Supports installing a `/Applications/T3 Code (Private).app` launcher. Subcommands: `start | foreground | build | install-app | uninstall-app | pair | log`.
- [`scripts/fork-migrate.sh`](./scripts/fork-migrate.sh) — One-way copy of projects, threads, attachments, settings, themes, keybindings, and provider credentials from an official T3 Code install (`~/.t3`) into `~/.t3-private`, stripping T3 Connect / cloud keys, auth sessions, and telemetry IDs (with automatic backup of previous fork data).
- [`scripts/fork-sync.sh`](./scripts/fork-sync.sh) — Rebase `privacy` onto upstream (`latest` release, `main`, or a specific tag), reinstall dependencies, run the telemetry privacy test, and rebuild.

### Quick Start (macOS)

```bash
git clone https://github.com/Unintendedz/t3code.git
cd t3code
pnpm install
./node_modules/.bin/vp run build:desktop

# Start the background server (uses ~/.t3-private on port 3780)
./scripts/fork-serve.sh start

# Pair a browser (over Tailscale by default, or pass --local for localhost)
./scripts/fork-serve.sh pair

# Optional: launch the desktop app (or install /Applications/T3 Code (Private).app)
./scripts/fork-desktop.sh start
./scripts/fork-desktop.sh install-app

# Optional: one-way migrate data from an existing official ~/.t3 install (quit official app first)
./scripts/fork-migrate.sh
```

To keep up with upstream later:

```bash
git remote add upstream https://github.com/pingdotgg/t3code.git
./scripts/fork-sync.sh        # latest upstream release (or pass `main` / `<tag>`)
./scripts/fork-serve.sh restart
```

---

<p align="center">
  <a href="https://t3.codes">
    <img src="./assets/prod/t3-black-web-icon-192x192.png" width="80" height="80" alt="T3 Code logo" />
  </a>
</p>

<h1 align="center">T3 Code</h1>

<p align="center">The open-source control plane for coding agents.</p>

<p align="center">
  <a href="https://t3.codes/download"><strong>Download</strong></a> ·
  <a href="https://apps.apple.com/us/app/t3-code-remote-claude-more/id6787819824">iOS</a> ·
  <a href="https://play.google.com/store/apps/details?id=com.t3tools.t3code">Android</a> ·
  <a href="https://app.t3.codes">Web</a> ·
  <a href="./docs/README.md">Docs</a> ·
  <a href="https://discord.gg/jn4EGJjrvv">Discord</a>
</p>

<p align="center">
  <a href="https://t3.codes">
    <img src="./.github/readme/hero.webp" width="100%" alt="T3 Code on desktop with a finished Claude thread, next to the phone app asking to approve a command from Codex" />
  </a>
</p>

T3 Code runs the coding agents on your machine and gives them one fast interface. Start a thread at your desk, then approve the next step from your phone.

It works with Claude Code, Codex, Cursor, OpenCode, Grok Build, Antigravity, Kiro, Pi, Muse Code, fx, and any [ACP](./docs/user/providers-acp.md) agent. If an agent is set up on your computer, T3 Code can control it.

## What you get

- **Your subscriptions.** T3 Code does not resell tokens. It drives the agents you are already signed in to.
- **Every agent in one place.** Change models in the middle of a thread. Let Claude hand a task to Codex.
- **Desktop, web, and phone.** One server, and every client shows the same threads. There are apps for iOS and Android.
- **Remote ready.** Run agents on any machine. Connect over your local network, Tailscale, or [T3 Connect](./docs/user/remote-access.md).
- **Git built in.** Each thread can work in its own worktree. Review the diff, then commit, push, and open a pull request with one button.
- **Fast.** Performance is a feature here. We measure it, and we treat a dropped frame as a bug.
- **Open.** Source code is MIT licensed. If you don't like something, fork it under your own branding (see [Trademarks and forks](#trademarks-and-forks)).

## Install

### Desktop app

[Download T3 Code](https://t3.codes/download) for macOS, Windows, or Linux. You can also use a package manager:

| Platform       | Command                                                              |
| -------------- | -------------------------------------------------------------------- |
| macOS          | `brew install --cask t3-code`                                        |
| Windows        | `winget install T3Tools.T3Code` or `scoop install extras/t3code`     |
| Arch Linux     | `yay -S t3code-bin`                                                  |
| Nix            | `nix profile add github:NixOS/nixpkgs/nixos-unstable#t3code`         |
| Debian, Ubuntu | `.deb` from [Releases](https://github.com/pingdotgg/t3code/releases) |

### Command line

This installs the `t3` command. Run `t3` to start the server and open the web app.

```bash
curl -fsSL https://t3.codes/install.sh | sh
```

On Windows, in PowerShell:

```powershell
irm https://t3.codes/install.ps1 | iex
```

To try it once without an install, run `npx t3@latest`.

### Phone

Get the app from the [App Store](https://apps.apple.com/us/app/t3-code-remote-claude-more/id6787819824) or [Google Play](https://play.google.com/store/apps/details?id=com.t3tools.t3code). Then follow [remote access](./docs/user/remote-access.md) to connect it to your computer.

### Sign in to an agent

T3 Code needs one agent that is installed and signed in. For example, install [Claude Code](https://claude.com/product/claude-code) and run `claude auth login`, or install [Codex CLI](https://developers.openai.com/codex/cli) and run `codex login`.

[Provider setup](./docs/user/install.md#providers) has the steps for each agent. [Install T3 Code](./docs/user/install.md) covers nightly builds, AppImage, WSL, and NixOS.

## "Wait, what are you selling me?"

Nothing. We built T3 Code because we wanted the best possible development experience with agents. We were inspired by existing solutions like the Codex desktop app, Conductor, Claude Desktop and Cursor Glass, but none met our bar.

We wanted something performant, remote-ready, and truly open. If we ever go the wrong direction, we want you to have everything you need to fork the source code and build the tool that you want, under your own name and branding.

## Documentation

- [Install and first run](./docs/user/install.md)
- [Remote access from a phone or another machine](./docs/user/remote-access.md)
- [Permission modes](./docs/user/permission-modes.md)
- [Source control](./docs/user/source-control.md)
- [Connect outside agents over MCP](./docs/user/outside-agents.md)
- [FAQ](./docs/user/faq.md)

[All docs](./docs/README.md) has the full list.

## Contributing

We have limited review capacity. Small, focused fixes are the most likely to be merged. Features need an approved discussion first.

- Read [CONTRIBUTING.md](./CONTRIBUTING.md) before you report a bug or open a pull request.
- Put feature requests in [Ideas](https://github.com/pingdotgg/t3code/discussions/categories/ideas).
- Build from source with the [development runbook](./docs/operations/00_development.md#first-checkout). The [architecture overview](./docs/internals/01_architecture.md) explains how it works.
- Get help in [Discord](https://discord.gg/jn4EGJjrvv).

## License

The source code in this repository is licensed under the [MIT License](./LICENSE).

## Trademarks and forks

The MIT license applies **only to the source code**. It does not grant any rights to T3 Tools, Inc.'s trademarks, branding, or trade dress, including the **T3 Code** name, wordmark, logos, and application icons.

If you fork, redistribute, or build on T3 Code's source code:

- **Use your own branding.** Replace the T3 Code name, wordmark, logos, and application icons in any public fork, redistributed build, website, package, or app store listing.
- **Be explicitly clear that your project is unofficial.** Do not use the T3 Code name, wordmark, logo, or branding in your own projects without making it unmistakably clear that your project is unofficial and not affiliated with or endorsed by T3 Tools, Inc.

Using our name, wordmark, logo, or branding in a way that suggests official status or affiliation is trademark infringement and unlawful. **Any project indicating or implying that it is an official version of T3 Code when it is not will be pursued to the full extent of the law.**

See [TRADEMARK.md](./TRADEMARK.md) for the full trademark and branding policy.
