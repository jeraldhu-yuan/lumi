# Contributing to Lumi

Thanks for helping make the desktop a little more alive.

## Setup

```bash
git clone https://github.com/jeraldhu-yuan/lumi.git
cd lumi
./script/build_and_run.sh   # build + launch
./script/test.sh            # run the test suite
```

Requirements: macOS 14+, Xcode Command Line Tools. No package dependencies.

## Ground rules

- **Tests must pass** — `./script/test.sh` runs in CI on every push and PR.
- **Wire formats are parsed in `StreamParsers.swift`**, never inline in a backend. That keeps protocol handling unit-testable; add fixtures for any new or changed message shape in `Tests/TestRunner/main.swift`.
- **Backends stay UI-free.** A backend talks through `AgentEvent`s; if you need new UI behavior, add an event or a capability flag instead of importing AppKit into a backend.
- **No new dependencies** without discussion — the zero-dependency build (SwiftPM *and* bare `swiftc`) is a feature.

## Good first contributions

- A new backend (Gemini CLI? a generic ACP adapter?) — see "Adding a backend" in [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).
- Interactive input support for Codex (`item/tool/requestUserInput`).
- New sprite sheets and animation states.
- A real screen-recorded demo video.

## Reporting bugs

Open an issue with macOS version, the backend you were using, and the output of `/usr/bin/log stream --predicate 'process == "Lumi"'` if relevant.
