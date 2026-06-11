# Lumi ✨

[![CI](https://github.com/jeraldhu-yuan/lumi/actions/workflows/ci.yml/badge.svg)](https://github.com/jeraldhu-yuan/lumi/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
![macOS 14+](https://img.shields.io/badge/macOS-14%2B-black)

**Lumi is a tiny fairy who lives on your desktop and talks to your AI.**

She flies, naps, gets curious, and watches your cursor. Click her, type a request, and she hands it to the coding agent of your choice — Codex or Claude Code — which works in your workspace and streams the answer back while she emotes along.

https://github.com/user-attachments/assets/ee137b4e-1128-4d24-b2ef-56fb5e3fd508

## Quick Start

```bash
git clone https://github.com/jeraldhu-yuan/lumi.git
cd lumi
./script/build_and_run.sh
```

Lumi appears on your desktop. Click her to open the prompt window, pick a backend from the dropdown, and ask away.

## Backends

| Backend | Needs | Notes |
|---|---|---|
| **Codex** (default) | Codex desktop app or CLI | Experimental `codex app-server` protocol |
| **Claude Code** | `claude` CLI installed and logged in | Headless `stream-json` mode; sessions resume across follow-ups |

Both are full agents: they run in your workspace, read and write files, and execute commands (gated by approvals below). Pick one from the dropdown in the prompt window (persisted), or pin it with `LUMI_BACKEND=codex|claude-code`.

## Approvals

When an agent backend wants to run a command, change files, or escalate permissions, Lumi shows an **Allow / Deny** dialog — nothing executes silently. (`LUMI_CODEX_AUTO_APPROVE=1` restores unattended mode for Codex if you really want it.)

Claude Code runs headless with `--permission-mode acceptEdits` by default; tune with `LUMI_CLAUDE_PERMISSION_MODE` (`default`, `acceptEdits`, `plan`, `bypassPermissions`).

## Configuration

All settings are environment variables, set before launch:

```bash
# Shared
LUMI_BACKEND="codex"                 # codex | claude-code
LUMI_WORKSPACE="$HOME/projects"      # the agent's working directory

# Codex
LUMI_CODEX_PATH="/Applications/Codex.app/Contents/Resources/codex"
LUMI_CODEX_SANDBOX="workspace-write"
LUMI_CODEX_APPROVAL_POLICY="on-request"
LUMI_CODEX_AUTO_APPROVE="1"          # skip approval dialogs

# Claude Code
LUMI_CLAUDE_PATH="/opt/homebrew/bin/claude"
LUMI_CLAUDE_PERMISSION_MODE="acceptEdits"
```

## Scripts

| Command | What it does |
|---|---|
| `./script/build_and_run.sh` | Build, stage `dist/Lumi.app`, and launch |
| `./script/build_and_run.sh --verify` | Build, launch, and assert the process is alive |
| `./script/test.sh` | Run the unit test suite |
| `./script/summon.sh` | Fast relaunch without rebuilding |

The build tries SwiftPM first and falls back to a direct `swiftc` build (the app has zero dependencies), so it works even on machines with a broken SwiftPM toolchain.

## Architecture

Lumi is plain Swift + AppKit, no dependencies. The interesting part is the backend abstraction:

```
SpriteWindowController      the fairy: animation state machine, desktop physics
PromptWindowController      HUD prompt window
AppDelegate                 glue: events -> moods -> UI
AgentBackend (protocol)     submit / cancel / reset + capability flags
 ├─ CodexBackend            codex app-server (JSON-RPC over stdio)
 └─ ClaudeCodeBackend       claude -p --output-format stream-json
StreamParsers / LineBuffer  pure wire-format parsing (unit tested)
```

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the full tour, including how to add a new backend in ~100 lines.

## Current Limits

- Interactive input prompts, MCP elicitations, and dynamic tool calls aren't surfaced in the UI for the Codex backend yet.
- Claude Code approvals are policy-based, not interactive — headless mode denies whatever the policy doesn't cover.
- The Codex app-server protocol is experimental and may change.

## Contributing

PRs welcome — see [CONTRIBUTING.md](CONTRIBUTING.md). The short version: `./script/test.sh` must pass, and new wire-format logic belongs in `StreamParsers.swift` where it can be tested.

## License

[MIT](LICENSE)
