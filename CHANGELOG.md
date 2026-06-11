# Changelog

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
