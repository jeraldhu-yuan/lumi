# Contributing to Lumi

Thank you for your interest in contributing.

## Development Setup

```bash
git clone https://github.com/jeraldhu-yuan/lumi.git
cd lumi
./script/build_and_run.sh   # build and launch
./script/test.sh            # run the test suite
```

Requirements: macOS 14+ and the Xcode Command Line Tools. The project has no third-party dependencies.

## Guidelines

- **Tests must pass.** `./script/test.sh` runs in CI on every push and pull request.
- **Wire-format parsing belongs in `StreamParsers.swift`**, not inline in a backend. This keeps protocol handling unit-testable; add fixtures to `Tests/TestRunner/main.swift` for any new or changed message shape.
- **Backends must remain UI-free.** A backend communicates exclusively through `AgentEvent` values. If new UI behavior is needed, add an event case or a capability flag rather than importing AppKit into a backend.
- **No new dependencies** without prior discussion. The zero-dependency build (SwiftPM and direct `swiftc`) is a deliberate property of the project.

## Suggested Contributions

- Additional agent backends — see "Adding a backend" in [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).
- Interactive input support for the Codex backend (`item/tool/requestUserInput`).
- Additional sprite sheets and animation states.

## Reporting Issues

Please include the macOS version, the active backend, reproduction steps, and — where relevant — output from:

```bash
/usr/bin/log stream --predicate 'process == "Lumi"'
```
