# Codex Desktop Sprite

A tiny macOS companion that keeps a cute floating Codex sprite on your desktop. Click the sprite, type a request, and it starts a Codex app-server thread rooted in your configured workspace.

This is an MVP. It uses the experimental `codex app-server` protocol exposed by the Codex desktop app CLI, so the adapter is intentionally isolated and easy to replace if the protocol changes.

https://github.com/user-attachments/assets/ee137b4e-1128-4d24-b2ef-56fb5e3fd508

## What Works

- Draggable desktop-level sprite that stays bounded to the visible desktop, with held, carried, and landing feedback.
- Current-desktop behavior: the sprite lives on the desktop instead of floating above active app windows.
- Intent-driven sprite behavior: standing blinks, generated sitting-blink sprite frame, cursor-proximity notice, prompt listening, input reading, thinking, working, success, failure, glances, reverse sleep wake-up, greeting, curiosity, two-frame directional flight, investigation, sitting, drowsy, and sleep states.
- Generated action sprites for directional flight, active-thread thinking, and the happy wave.
- Generated in-between frames smooth the notice -> listening -> reading -> thinking -> working progression instead of randomly cycling through poses.
- Curiosity is not always movement: the sprite sometimes just looks around, and only sometimes decides to fly somewhere, investigate, then return to idle.
- Click-to-open prompt window.
- Starts one persisted Codex thread with a workspace `cwd`.
- Shows streamed Codex response text inside the prompt panel.
- Sends follow-up prompts into the active thread with `thread/resume`.
- `New Thread` clears the active thread and starts fresh on the next prompt.
- Opens Codex Desktop for the configured workspace.

## Sprite Assets

The repo includes the runtime sprite sheets used by the app:

- `Assets/ChibiAssistant/sprite-sheet.png`
- `Assets/ChibiAssistant/generated/standing-orientations/standing-orientations-sheet.png`
- `Assets/ChibiAssistant/generated/sitting-orientations/sitting-orientations-sheet.png`
- `Assets/ChibiAssistant/generated/sleep-wake/sleep-wake-sheet.png`
- `Assets/ChibiAssistant/generated/action-sprites/action-sprites-sheet.png`

## Defaults

- Codex CLI: `/Applications/Codex.app/Contents/Resources/codex`
- Workspace: `~/CODEX - DIGITAL ASSISTANT TASKS`
- Sandbox: `workspace-write`
- Approval policy: `on-request`
- Approval handling: sprite-launched turns auto-approve app-server command, file-change, and permission requests for the active turn/session because the sprite does not yet have a full approval UI.

Override the local defaults when launching:

```bash
CODEX_SPRITE_WORKSPACE="/path/to/workspace" \
CODEX_SPRITE_CODEX_PATH="/Applications/Codex.app/Contents/Resources/codex" \
CODEX_SPRITE_SANDBOX="workspace-write" \
CODEX_SPRITE_APPROVAL_POLICY="on-request" \
./script/build_and_run.sh
```

## Run

```bash
./script/build_and_run.sh
```

The script tries SwiftPM first, stages `dist/CodexSprite.app`, and launches it as a real macOS app bundle. If SwiftPM manifest loading is broken on the local machine, it falls back to a direct `swiftc` build because the MVP has no package dependencies.

## Verify

```bash
./script/build_and_run.sh --verify
```

## Summon

Fast restart without rebuilding when `dist/CodexSprite.app` already exists:

```bash
./script/summon.sh
```

You can also double-click `Summon Codex Sprite.command` in Finder.

## Current Limits

- Interactive input prompts, MCP elicitations, and dynamic tool calls are not yet handled inside the sprite UI. Open Codex Desktop if a turn needs those.
- The app-server protocol is experimental.
- Thread deep-linking into Codex Desktop is not implemented; the `Open Codex` button opens the configured workspace.
- The README GIF is generated from sprite frames. A real desktop interaction video should be recorded separately before a polished public launch.

## License

MIT
