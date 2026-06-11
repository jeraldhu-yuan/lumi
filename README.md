# Lumi

[![CI](https://github.com/jeraldhu-yuan/lumi/actions/workflows/ci.yml/badge.svg)](https://github.com/jeraldhu-yuan/lumi/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
![macOS 14+](https://img.shields.io/badge/macOS-14%2B-black)

Lumi is a macOS desktop agent supervisor. A small animated sprite lives on the desktop and maintains one durable master conversation per provider. Lumi understands the request, keeps the master context concise, and coordinates native Codex or Claude Code agents to perform work in a configured workspace.

https://github.com/user-attachments/assets/ee137b4e-1128-4d24-b2ef-56fb5e3fd508

## Features

- **Animated desktop presence** — a sprite with an intent-driven animation state machine: idle, listening, reading, thinking, working, awaiting approval, success, and failure states, plus autonomous behaviors (cursor tracking, curiosity flights, sitting, sleeping).
- **Persistent master sessions** — one resumable Lumi master thread per provider and workspace, restored across app launches.
- **Native agent coordination** — Codex and Claude Code retain their own subagents, goals, compaction, memory, and workflow facilities. Lumi does not invent a shared command language.
- **Provider adapters** — OpenAI Codex via `codex app-server` and Anthropic Claude Code via the headless CLI's `stream-json` interface.
- **Human-in-the-loop approvals** — command execution, file changes, and permission escalations surface as Allow/Deny dialogs on both backends; nothing runs silently.
- **Live activity** — tool calls, edits, and subagent work surface as a progress line so you can see what the agent is doing.
- **Persistent Claude Code session** — one long-lived process per master session; follow-up prompts skip the cold start and continue the same in-process conversation.
- **Streaming and cancellation** — responses stream into the prompt window token by token and in-flight requests can be stopped.
- **Desktop-native composer** — multiline input, Undo/Cut/Copy/Paste/Select All, file picker, pasted images, attachment chips, and file/folder drag-and-drop. Files may also be dropped directly onto the sprite.
- **Readable conversations** — user and Lumi messages render separately with Markdown formatting and clickable links.
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
3. Type a goal and press Command-Return. Follow-ups continue Lumi's durable master session for that provider.
4. When the agent requests permission to run a command or modify files, respond to the Allow/Deny dialog.
5. Paste, choose, or drag files and folders into the composer. You can also drop them directly onto Lumi; she stages them and waits for instructions.

The active provider remains visible because its native controls differ. Claude Code includes commands such as `/goal`, `/compact`, `/fork`, `/loop`, and `/batch`. Codex exposes goals, compaction, thread forks, memories, and subagents through app-server and agent tools. Lumi uses only capabilities exposed by the active runtime.

## Configuration

All settings are environment variables read at launch.

| Variable | Default | Description |
|---|---|---|
| `LUMI_BACKEND` | `codex` | Active backend: `codex` or `claude-code` |
| `LUMI_WORKSPACE` | `~/CODEX - DIGITAL ASSISTANT TASKS` | Working directory for the agent |
| `LUMI_PERSONA` | built-in | System-prompt persona injected into every backend |
| `LUMI_SUPERVISOR_INSTRUCTIONS` | built-in | Replace the complete master-coordinator instructions |
| `LUMI_OPEN_PROMPT_ON_LAUNCH` | unset | Set to `1` to open the prompt immediately for development |
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

Tests cover stream parsing, request attachment handling, and master-session persistence. They run as a plain executable, so they work with or without a functional SwiftPM installation. CI builds the app and runs the suite on macOS for every push and pull request.

## Architecture

```
SpriteWindowController      sprite window: animation state machine, desktop movement
PromptWindowController      prompt window: transcript, input, backend selector
ConversationTranscriptView structured Markdown conversation rendering
PromptComposerView          native editing, attachments, pasteboard, drag/drop
AppDelegate                 event-to-UI glue on the main actor
MasterSessionStore          durable provider/workspace master session IDs
AgentBackend (protocol)     submit / cancel / reset + capability flags
 ├─ CodexBackend            codex app-server (JSON-RPC over stdio)
 └─ ClaudeCodeBackend       claude -p --output-format stream-json
StreamParsers / LineBuffer  pure wire-format parsing (unit tested)
```

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for a complete overview, including the steps to add a new backend.

## Known Limitations

- Interactive input requests, MCP elicitations, and dynamic tool calls from the Codex backend are not yet surfaced in the UI.
- The Codex backend starts a fresh `app-server` process per turn; the Claude Code backend keeps one process alive per session.
- The Codex app-server protocol is experimental and subject to upstream change.

## Contributing

Contributions are welcome — see [CONTRIBUTING.md](CONTRIBUTING.md).

## License

[MIT](LICENSE)
