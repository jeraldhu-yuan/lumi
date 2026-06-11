# Changelog

## 0.5.0 - 2026-06-11

### Added
- Durable Lumi master sessions, stored separately for each provider and workspace and restored across launches.
- Provider-specific coordinator instructions using Codex and Claude Code's native subagents, goals, compaction, memory, and workflow facilities.
- Structured Markdown conversation rendering with separate user, Lumi, and status messages.
- Auto-growing native composer with standard Edit commands, Control-A Select All, attachment chips, file picker, pasted images, and drag/drop.
- File and folder drops directly onto the Lumi sprite, with a receiving highlight and short success animation.

### Changed
- Codex supervisor instructions now use app-server `developerInstructions` instead of modifying the first user message.
- Claude Code receives workspace `AGENTS.md` guidance so both providers share the same durable workspace context.
- The prompt panel is wider and less compressed, with corrected caret and placeholder alignment.

## 0.4.1 — 2026-06-10

### Added
- Shared assistant persona (`LUMI_PERSONA`): the assistant identifies as Lumi regardless of the active engine. Delivered via `--append-system-prompt` for Claude Code and a first-turn preamble for Codex.
- Lingering click greeting: hearts float up after release, the greeting sequence plays out fully before cursor-gaze tracking takes over.

### Fixed
- Character size and baseline now normalized across sprite sheets at draw time; sitting, sleeping, and expression frames previously rendered up to 16% larger and on a different ground line than standing frames.
- Clicking the sprite while it sat no longer plays the wake-from-sleep eye-rub sequence; it greets from the seat, stands, and waves.
- Transcript labels the assistant's turns "Lumi" instead of the backend name.

## 0.4.0 — 2026-06-10

### Changed
- **Agents only.** Removed the Claude API and OpenAI-compatible chat backends — Lumi connects exclusively to coding agents (Codex, Claude Code) that can act in your workspace. `ANTHROPIC_API_KEY` / `LUMI_OPENAI_*` / `LUMI_SYSTEM_PROMPT` settings are gone.
- Prompt window collapses into a compact ask bar when idle; the transcript floats on the window blur and appears only during a conversation.

### Added
- Seven hand-drawn expression sprites (pleading, talking x3, dizzy, celebrate, listening) wired into approvals, streaming, failure, success, and listening states, plus the `tools/process_expressions.swift` pipeline that produced them.

### Removed
- Procedural pixel-person fallback renderer (a leftover placeholder character).

## 0.3.0 — 2026-06-10

**The Lumi release.** Codex Desktop Sprite is now Lumi, a backend-agnostic desktop AI companion.

### Added
- Pluggable `AgentBackend` protocol with four backends: Codex, Claude Code (headless CLI), Claude API, and any OpenAI-compatible endpoint (Ollama, LM Studio, OpenRouter, ...).
- Backend picker in the prompt window, persisted across launches.
- Interactive **Allow / Deny approval dialogs** for agent actions (replaces silent auto-approve; `LUMI_CODEX_AUTO_APPROVE=1` opts back in).
- Stop button to cancel an in-flight request.
- Unit test suite (`script/test.sh`) covering line buffering and all three streaming wire formats, plus GitHub Actions CI.
- `docs/ARCHITECTURE.md`, `CONTRIBUTING.md`, this changelog.

### Changed
- Renamed: app is `Lumi.app`, repo is `lumi`, env vars use the `LUMI_*` prefix (old `CODEX_SPRITE_*` / `SPRITE_*` names removed).
- Prompt window redesigned as a clean HUD panel: hidden titlebar, rounded panels, placeholder text, icon controls.
- Stream parsing extracted into pure, tested units (`LineBuffer`, `StreamParsers`).

## 0.1.0 — 2026-06-06

- Initial MVP: floating Codex sprite with intent-driven animations, prompt window, and `codex app-server` integration.
