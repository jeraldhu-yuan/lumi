#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

mkdir -p .build

# The test runner compiles only the pure, AppKit-free sources so it runs
# anywhere swiftc does — no SwiftPM, no XCTest, no GUI session required.
xcrun swiftc -swift-version 5 \
  Sources/Lumi/LineBuffer.swift \
  Sources/Lumi/StreamParsers.swift \
  Sources/Lumi/ConversationModels.swift \
  Sources/Lumi/AgentBackend.swift \
  Sources/Lumi/MasterSessionStore.swift \
  Sources/Lumi/LumiContextStore.swift \
  Sources/Lumi/CodexSessionRecovery.swift \
  Tests/TestRunner/main.swift \
  -o .build/lumi-tests

exec .build/lumi-tests
