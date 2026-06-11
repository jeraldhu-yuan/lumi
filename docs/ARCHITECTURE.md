# Lumi Architecture

Lumi is a single-target Swift + AppKit application with no third-party dependencies. All source lives in `Sources/Lumi/`.

## Windows

- **`SpriteWindowController`** — the desktop sprite: a borderless, desktop-level window running an intent-driven animation state machine (idle, listening, reading, thinking, working, asking, success, failure, plus autonomous sleep/curiosity behaviors). It has no knowledge of AI backends; its public surface is `setMood(_:)` and `face(point:)`.
- **`PromptWindowController` / `PromptView`** — window scaffolding, provider selection, status, and master-thread controls. The panel rests at a spacious compact height and expands when a conversation produces output.
- **`ConversationTranscriptView`** — renders structured user, Lumi, and status messages with Markdown styling and clickable links.
- **`PromptComposerView`** — owns the native text view, attachment chips, file picker, pasteboard handling, auto-growing input, and drag/drop.

## Backend Abstraction

`AgentBackend` is the seam that keeps the application engine-agnostic:

```swift
protocol AgentBackend: AnyObject {
    var kind: BackendKind { get }
    var capabilities: BackendCapabilities { get }
    func submit(request:workspacePath:existingSessionId:onEvent:)
    func cancel()
    func reset()
}
```

Backends emit a small event vocabulary (`AgentEvent`): `status`, `sessionStarted`, `delta`, `approvalRequest`, `completed`, `failed`. `AppDelegate` is the sole consumer and maps events to sprite moods and prompt-window updates on the main actor.

`BackendCapabilities` flags (`usesWorkspace`, `supportsApprovals`, `canOpenCompanionApp`) drive conditional UI — for example, only the Codex backend exposes an "Open Codex Desktop" control.

### Backends

| Backend | Transport | Session continuity |
|---|---|---|
| `CodexBackend` | `codex app-server --stdio`, JSON-RPC per turn | `thread/start` / `thread/resume` |
| `ClaudeCodeBackend` | `claude -p --output-format stream-json` subprocess per turn | `--resume <session-id>` |

Both backends are full agents: they operate in a configured workspace and emit `approvalRequest` events before acting on it. Lumi intentionally supports only agent backends; chat-only integrations were removed in 0.4.0.

### Supervisor Instructions

`AppConfig.supervisorInstructions(for:)` combines Lumi's identity with a strict master-coordinator role and provider-specific capability guidance. Claude Code receives it through `--append-system-prompt`; Codex receives it as app-server `developerInstructions` when the master thread starts. The instructions require native provider capabilities and prohibit invented commands.

Codex discovers the workspace `AGENTS.md` normally. Claude Code does not read `AGENTS.md` by default, so Lumi includes the workspace copy in Claude's supervisor instructions to keep durable guidance consistent across providers.

### Master Sessions

`MasterSessionStore` persists one session identifier for each provider/workspace pair in `UserDefaults`. Switching providers restores that provider's master session; the new-thread button clears only the active provider's master.

### Attachments

`AgentRequest` carries text plus typed local attachments. Codex receives images as `localImage` input and files/folders as app-server `mention` input. Claude Code receives absolute paths in the prompt and `--add-dir` access for their parent directories. The composer accepts pasted file URLs and images; the sprite accepts file/folder drops and forwards them to the same composer pipeline.

### Parsing

Wire-format handling is separated from I/O:

- **`LineBuffer`** — converts arbitrary stream chunks into complete newline-delimited lines, handling partial lines and multi-byte UTF-8 sequences split across chunks.
- **`StreamParsers.swift`** — `ClaudeCodeStreamParser`: maps one `stream-json` line to one typed event. Stateless, no I/O.

This layer is what `script/test.sh` exercises. When an upstream protocol changes, the fix and its regression test land in the same file.

## Adding a Backend

1. Create `MyBackend.swift` conforming to `AgentBackend` (roughly 100 lines; use the closest existing backend as a template).
2. If it has a streaming wire format, place the line-to-event mapping in `StreamParsers.swift` and add fixtures to `Tests/TestRunner/main.swift`.
3. Add a case to `BackendKind` (raw value, display name, selector detail) and `BackendFactory`.
4. Add any settings to `AppConfig` using the `LUMI_*` environment-variable convention.

The UI picks the backend up automatically — the selector iterates `BackendKind.allCases`.

## Sprite Rendering

Sprite sheets are 256 px-per-frame horizontal strips loaded from the app bundle (with a source-tree fallback for development). Frames are addressed by per-sheet integer offsets (`standingFrameOffset`, `expressionFrameOffset`, etc.).

Because the sheets were generated in separate batches, the character is not the same size or on the same baseline in each. `SpriteSheet` carries measured `contentScale` and `bottomGap` values, and the renderer normalizes every frame to the standing sheet's proportions at draw time so the character's size and ground line remain constant across states.

`tools/process_expressions.swift` is the asset pipeline for new sheets: it chroma-keys green-screen art, detects sprites by column runs, normalizes scale, and packs a strip sheet.

## Build System

`script/build_and_run.sh` attempts `swift build` and falls back to invoking `swiftc` directly on `Sources/Lumi/*.swift` (possible because there are no package dependencies). It then stages a complete `.app` bundle in `dist/` with sprite sheets copied into Resources. `script/test.sh` compiles the parsing layer plus the test runner the same way, so neither path requires a working SwiftPM installation.

## Threading Model

- Subprocess backends serialize all state on a private `DispatchQueue`; pipe readability handlers hop onto it.
- `AgentEvent` callbacks may arrive on any thread; `AppDelegate` re-dispatches to the main actor before touching UI.
