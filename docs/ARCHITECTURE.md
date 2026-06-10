# Lumi Architecture

Lumi is a single-target Swift + AppKit app with zero dependencies. Everything lives in `Sources/Lumi/`.

## The two windows

- **`SpriteWindowController`** — the fairy herself. A borderless desktop-level window running an intent-driven animation state machine (idle, listening, reading, thinking, working, success, failure, sleep, curiosity flights). It knows nothing about AI; it just exposes `setMood(_:)` and `face(point:)`.
- **`PromptWindowController` / `PromptView`** — the HUD prompt panel: transcript, input, backend picker, status line, and the send/stop button. It forwards user intent through closures and renders whatever `AppDelegate` tells it to.

## The backend abstraction

`AgentBackend` is the seam that makes Lumi model-agnostic:

```swift
protocol AgentBackend: AnyObject {
    var kind: BackendKind { get }
    var capabilities: BackendCapabilities { get }
    func submit(prompt:workspacePath:existingSessionId:onEvent:)
    func cancel()
    func reset()
}
```

Backends emit a small event vocabulary (`AgentEvent`): `status`, `sessionStarted`, `delta`, `approvalRequest`, `completed`, `failed`. `AppDelegate` is the only consumer — it maps events to sprite moods and prompt-window updates on the main actor.

`BackendCapabilities` flags (`usesWorkspace`, `supportsApprovals`, `canOpenCompanionApp`) drive what the UI shows, so chat backends don't render a workspace path and agent backends get approval dialogs.

### The four backends

| Backend | Transport | Sessions |
|---|---|---|
| `CodexBackend` | `codex app-server --stdio`, JSON-RPC per turn | `thread/start` / `thread/resume` |
| `ClaudeCodeBackend` | `claude -p --output-format stream-json` subprocess per turn | `--resume <session-id>` |
| `AnthropicBackend` | HTTPS SSE to `api.anthropic.com/v1/messages` | in-memory message history |
| `OpenAICompatibleBackend` | HTTPS SSE to any `chat/completions` | in-memory message history |

### Parsing is pure and tested

Wire-format handling is deliberately separated from I/O:

- **`LineBuffer`** — turns arbitrary stream chunks into complete newline-delimited lines (handles partial lines and multi-byte UTF-8 splits).
- **`StreamParsers.swift`** — `ClaudeCodeStreamParser`, `AnthropicSSEParser`, `OpenAIChunkParser`: one line in, one typed event out. No state, no sockets.

This is what `script/test.sh` exercises. If a protocol changes upstream, the fix and its regression test both land in one file.

## Adding a backend

1. Create `MyBackend.swift` conforming to `AgentBackend` (~100 lines; copy the closest existing one).
2. If it has a streaming wire format, put the line-to-event mapping in `StreamParsers.swift` and add fixtures to `Tests/TestRunner/main.swift`.
3. Add a case to `BackendKind` (raw value, display name) and `BackendFactory`.
4. Add any settings to `AppConfig` (`LUMI_*` env vars).

The UI picks it up automatically — the picker iterates `BackendKind.allCases`.

## Build system

`script/build_and_run.sh` tries `swift build` first and falls back to invoking `swiftc` directly on `Sources/Lumi/*.swift` (possible because there are no package dependencies). It then stages a real `.app` bundle in `dist/` with the sprite sheets copied into Resources. Tests build the same way via `script/test.sh`, so neither path requires a working SwiftPM.

## Threading model

- Subprocess backends (`Codex`, `ClaudeCode`) serialize all state on a private `DispatchQueue`; pipe readability handlers hop onto it.
- HTTP backends run one `Task` per turn and allow a single in-flight request.
- `AgentEvent` callbacks may arrive on any thread; `AppDelegate` re-dispatches to the main actor before touching UI.
