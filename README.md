# Lumi

[![CI](https://github.com/jeraldhu-yuan/lumi/actions/workflows/ci.yml/badge.svg)](https://github.com/jeraldhu-yuan/lumi/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
![macOS 14+](https://img.shields.io/badge/macOS-14%2B-black)

Lumi is a macOS desktop companion that provides an ambient, animated interface to local coding agents. A small animated sprite lives on the desktop; clicking it opens a compact prompt window that routes requests to a coding agent running in a configured workspace, streams the response, and requires explicit user approval before the agent executes commands or modifies files.

https://github.com/user-attachments/assets/ee137b4e-1128-4d24-b2ef-56fb5e3fd508

## Features

- **Animated desktop presence** — a sprite with an intent-driven animation state machine: idle, listening, reading, thinking, working, awaiting approval, success, and failure states, plus autonomous behaviors (cursor tracking, curiosity flights, sitting, sleeping).
- **Pluggable agent backends** — a common `AgentBackend` protocol with two implementations: OpenAI Codex (via the `codex app-server` JSON-RPC protocol) and Anthropic Claude Code (via the headless CLI's `stream-json` interface). Sessions persist across follow-up prompts.
- **Human-in-the-loop approvals** — command execution, file changes, and permission escalations surface as Allow/Deny dialogs; nothing runs silently.
- **Streaming and cancellation** — responses stream into the prompt window token by token and in-flight requests can be stopped.
- **Zero dependencies** — plain Swift and AppKit. Builds with SwiftPM or, as a fallback, a direct `swiftc` invocation.

## Requirements

- macOS 14 or later
- Xcode Command Line Tools
- At least one agent:
  - **Codex** — the Codex desktop app (bundled CLI) or a standalone `codex` binary
  - **Claude Code** — `npm install -g @anthropic-ai/claude-code`, authenticated via `claude` login

## Installation

```bash
git clone https://github.com/jeraldhu-yuan/lumi.git
cd lumi
./script/build_and_run.sh
```

The build script stages and launches `dist/Lumi.app`. It attempts a SwiftPM build first and falls back to a direct `swiftc` build, so a fully working SwiftPM toolchain is not required.

## Usage

1. Click the sprite to open the prompt window.
2. Select a backend from the selector (the choice persists across launches).
3. Type a request and press ⌘↩. The agent runs in the configured workspace; follow-up prompts continue the same session.
4. When the agent requests permission to run a command or modify files, respond to the Allow/Deny dialog.

## Configuration

All settings are environment variables read at launch.

| Variable | Default | Description |
|---|---|---|
| `LUMI_BACKEND` | `codex` | Active backend: `codex` or `claude-code` |
| `LUMI_WORKSPACE` | `~/CODEX - DIGITAL ASSISTANT TASKS` | Working directory for the agent |
| `LUMI_PERSONA` | built-in | System-prompt persona injected into every backend |
| `LUMI_CODEX_PATH` | auto-detected | Path to the `codex` binary |
| `LUMI_CODEX_SANDBOX` | `workspace-write` | Codex sandbox mode |
| `LUMI_CODEX_APPROVAL_POLICY` | `on-request` | Codex approval policy |
| `LUMI_CODEX_AUTO_APPROVE` | unset | Set to `1` to bypass approval dialogs |
| `LUMI_CLAUDE_PATH` | auto-detected | Path to the `claude` binary |
| `LUMI_CLAUDE_PERMISSION_MODE` | `acceptEdits` | Claude Code permission mode (`default`, `acceptEdits`, `plan`, `bypassPermissions`) |

## Development

| Command | Description |
|---|---|
| `./script/build_and_run.sh` | Build, stage `dist/Lumi.app`, and launch |
| `./script/build_and_run.sh --build` | Build and stage only (used by CI) |
| `./script/build_and_run.sh --verify` | Build, launch, and assert the process is running |
| `./script/test.sh` | Run the unit test suite |
| `./script/summon.sh` | Relaunch without rebuilding |

Tests cover the stream-parsing layer and run as a plain executable, so they work with or without a functional SwiftPM installation. CI builds the app and runs the suite on macOS for every push and pull request.

## Architecture

```
SpriteWindowController      sprite window: animation state machine, desktop movement
PromptWindowController      prompt window: transcript, input, backend selector
AppDelegate                 event-to-UI glue on the main actor
AgentBackend (protocol)     submit / cancel / reset + capability flags
 ├─ CodexBackend            codex app-server (JSON-RPC over stdio)
 └─ ClaudeCodeBackend       claude -p --output-format stream-json
StreamParsers / LineBuffer  pure wire-format parsing (unit tested)
```

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for a complete overview, including the steps to add a new backend.

## Known Limitations

- Interactive input requests, MCP elicitations, and dynamic tool calls from the Codex backend are not yet surfaced in the UI.
- Claude Code approvals are policy-based (`--permission-mode`) rather than interactive; actions outside the configured policy are denied.
- The Codex app-server protocol is experimental and subject to upstream change.

## Contributing

Contributions are welcome — see [CONTRIBUTING.md](CONTRIBUTING.md).

## License

[MIT](LICENSE)
