# Codex Desktop Sprite

A tiny macOS companion that keeps a cute floating sprite on your desktop. Click the sprite, type a request, and it talks to your AI of choice — Codex, Claude Code, the Claude API, or any OpenAI-compatible endpoint (Ollama, LM Studio, OpenRouter, ...).

![Codex Desktop Sprite demo](docs/media/sprite-demo.gif)

## Backends

Pick a backend from the dropdown in the prompt window (persisted across launches), or set `SPRITE_BACKEND` to `codex`, `claude-code`, `anthropic`, or `openai`.

| Backend | Kind | Needs | Notes |
|---|---|---|---|
| **Codex** (default) | Agent with workspace | Codex desktop app or CLI | Uses the experimental `codex app-server` protocol |
| **Claude Code** | Agent with workspace | `claude` CLI installed and logged in | Headless `claude -p --output-format stream-json`, sessions resume across follow-ups |
| **Claude** | Chat | `ANTHROPIC_API_KEY` | Direct Claude API streaming (`claude-opus-4-8` by default) |
| **Local Model** | Chat | An OpenAI-compatible server | Defaults to Ollama at `http://localhost:11434/v1` |

Agent backends run with a workspace and can read/write files and run commands. Chat backends are pure conversation — no workspace, no approvals needed.

## Approvals

When Codex asks to run a command, change files, or get extra permissions, the sprite now shows an Allow/Deny dialog instead of silently approving. Set `CODEX_SPRITE_AUTO_APPROVE=1` to restore the old auto-approve behavior.

Claude Code runs headless with `--permission-mode acceptEdits` by default; override with `CLAUDE_SPRITE_PERMISSION_MODE` (`default`, `acceptEdits`, `plan`, `bypassPermissions`).

## What Works

- Draggable desktop-level sprite that stays bounded to the visible desktop, with held, carried, and landing feedback.
- Intent-driven sprite behavior: standing blinks, cursor-proximity notice, prompt listening, input reading, thinking, working, success, failure, glances, sleep states, curiosity flights, and more.
- Click-to-open prompt window with streamed responses.
- Pluggable AI backends with a session per conversation and follow-up support.
- Stop button to cancel a running request.
- Approval dialogs for agent actions (Codex backend).
- `New Session` clears the active session and starts fresh on the next prompt.
- Opens Codex Desktop for the configured workspace (Codex backend).

## Configuration

Everything is configured with environment variables (set them before launching):

```bash
# Shared
SPRITE_BACKEND="codex"              # codex | claude-code | anthropic | openai
CODEX_SPRITE_WORKSPACE="$HOME/some/workspace"   # workspace for agent backends
SPRITE_SYSTEM_PROMPT="..."          # system prompt for chat backends

# Codex
CODEX_SPRITE_CODEX_PATH="/Applications/Codex.app/Contents/Resources/codex"
CODEX_SPRITE_SANDBOX="workspace-write"
CODEX_SPRITE_APPROVAL_POLICY="on-request"
CODEX_SPRITE_AUTO_APPROVE="1"       # skip approval dialogs (old behavior)

# Claude Code
CLAUDE_SPRITE_CLAUDE_PATH="/opt/homebrew/bin/claude"
CLAUDE_SPRITE_PERMISSION_MODE="acceptEdits"

# Claude API
ANTHROPIC_API_KEY="sk-ant-..."
SPRITE_ANTHROPIC_MODEL="claude-opus-4-8"

# OpenAI-compatible
SPRITE_OPENAI_BASE_URL="http://localhost:11434/v1"
SPRITE_OPENAI_MODEL="llama3.2"
SPRITE_OPENAI_API_KEY=""            # optional, for hosted endpoints
```

## Run

```bash
./script/build_and_run.sh
```

The script tries SwiftPM first, stages `dist/Sprite.app`, and launches it as a real macOS app bundle. If SwiftPM manifest loading is broken on the local machine, it falls back to a direct `swiftc` build because the app has no package dependencies.

## Verify

```bash
./script/build_and_run.sh --verify
```

## Summon

Fast restart without rebuilding when `dist/Sprite.app` already exists:

```bash
./script/summon.sh
```

You can also double-click `Summon Codex Sprite.command` in Finder.

## Sprite Assets

The repo includes the runtime sprite sheets used by the app:

- `Assets/ChibiAssistant/sprite-sheet.png`
- `Assets/ChibiAssistant/generated/standing-orientations/standing-orientations-sheet.png`
- `Assets/ChibiAssistant/generated/sitting-orientations/sitting-orientations-sheet.png`
- `Assets/ChibiAssistant/generated/sleep-wake/sleep-wake-sheet.png`
- `Assets/ChibiAssistant/generated/action-sprites/action-sprites-sheet.png`

## Current Limits

- Interactive input prompts, MCP elicitations, and dynamic tool calls are not yet handled inside the sprite UI for the Codex backend.
- Claude Code approvals are policy-based (`--permission-mode`), not interactive — headless mode denies tools the policy doesn't cover.
- The Codex app-server protocol is experimental.
- Thread deep-linking into Codex Desktop is not implemented; the `Open Codex` button opens the configured workspace.
- The README GIF is generated from sprite frames. A real desktop interaction video should be recorded separately before a polished public launch.

## License

MIT
