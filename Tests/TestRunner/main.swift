import Foundation

// Lumi's test runner is a plain executable rather than an XCTest bundle so it
// runs identically through SwiftPM, the swiftc fallback path, and CI.

var passed = 0
var failures: [String] = []

func expect(_ condition: @autoclosure () -> Bool, _ name: String) {
    if condition() {
        passed += 1
    } else {
        failures.append(name)
        print("FAIL: \(name)")
    }
}

func data(_ string: String) -> Data { Data(string.utf8) }

// MARK: - LineBuffer

do {
    var buffer = LineBuffer()
    expect(buffer.append(data("hel")).isEmpty, "LineBuffer holds a partial line")
    expect(buffer.append(data("lo\nwor")) == [data("hello")], "LineBuffer yields a completed line and keeps the remainder")
    expect(buffer.append(data("ld\n\nx\n")) == [data("world"), data("x")], "LineBuffer skips blank lines and yields multiple lines per chunk")
    expect(buffer.append(Data()).isEmpty, "LineBuffer tolerates empty chunks")

    var split = LineBuffer()
    let utf8Split = Data("héllo\n".utf8)
    let first = split.append(utf8Split.prefix(3))
    let second = split.append(utf8Split.dropFirst(3))
    expect(first.isEmpty && second == [data("héllo")], "LineBuffer reassembles multi-byte UTF-8 split across chunks")
}

// MARK: - ClaudeCodeStreamParser

do {
    let initLine = #"{"type":"system","subtype":"init","session_id":"abc-123"}"#
    expect(ClaudeCodeStreamParser.parse(line: data(initLine)) == .sessionStarted(id: "abc-123"), "claude-code: init yields sessionStarted")

    let delta = #"{"type":"stream_event","event":{"type":"content_block_delta","delta":{"type":"text_delta","text":"hi"}}}"#
    expect(ClaudeCodeStreamParser.parse(line: data(delta)) == .textDelta("hi"), "claude-code: text_delta yields textDelta")

    let thinking = #"{"type":"stream_event","event":{"type":"content_block_delta","delta":{"type":"thinking_delta","thinking":"hmm"}}}"#
    expect(ClaudeCodeStreamParser.parse(line: data(thinking)) == nil, "claude-code: thinking deltas are ignored")

    let success = #"{"type":"result","subtype":"success","is_error":false,"result":"done!","session_id":"abc-123"}"#
    expect(ClaudeCodeStreamParser.parse(line: data(success)) == .success(sessionId: "abc-123", finalText: "done!"), "claude-code: success result")

    let failure = #"{"type":"result","is_error":true,"result":"boom"}"#
    expect(ClaudeCodeStreamParser.parse(line: data(failure)) == .failure("boom"), "claude-code: error result yields failure")

    let emptyError = #"{"type":"result","is_error":true}"#
    expect(ClaudeCodeStreamParser.parse(line: data(emptyError)) == .failure("Claude Code turn failed."), "claude-code: empty error gets a default message")

    expect(ClaudeCodeStreamParser.parse(line: data("not json")) == nil, "claude-code: garbage lines are ignored")
    expect(ClaudeCodeStreamParser.parse(line: data(#"{"type":"assistant"}"#)) == nil, "claude-code: unrelated message types are ignored")
}

// MARK: - BackendKind

do {
    expect(BackendKind(rawValue: "claude-code") == .claudeCode, "backend kinds: claude-code raw value round-trips")
    expect(BackendKind.allCases.count == 2, "backend kinds: two agent backends registered")
    expect(Set(BackendKind.allCases.map(\.displayName)).count == 2, "backend kinds: display names are unique")
}

// MARK: - Summary

if failures.isEmpty {
    print("All \(passed) tests passed.")
    exit(0)
} else {
    print("\(passed) passed, \(failures.count) FAILED")
    exit(1)
}
