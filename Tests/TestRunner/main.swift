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

// MARK: - AnthropicSSEParser

do {
    let delta = #"data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Hello"}}"#
    expect(AnthropicSSEParser.parse(line: delta) == .textDelta("Hello"), "anthropic: text_delta yields textDelta")

    let noSpace = #"data:{"type":"content_block_delta","delta":{"type":"text_delta","text":"x"}}"#
    expect(AnthropicSSEParser.parse(line: noSpace) == .textDelta("x"), "anthropic: data: framing without space is tolerated")

    expect(AnthropicSSEParser.parse(line: "event: content_block_delta") == nil, "anthropic: event lines are ignored")
    expect(AnthropicSSEParser.parse(line: #"data: {"type":"message_stop"}"#) == .messageStop, "anthropic: message_stop terminates")

    let thinking = #"data: {"type":"content_block_delta","delta":{"type":"thinking_delta","thinking":"..."}}"#
    expect(AnthropicSSEParser.parse(line: thinking) == nil, "anthropic: thinking deltas are ignored")

    let error = #"data: {"type":"error","error":{"type":"overloaded_error","message":"Overloaded"}}"#
    expect(AnthropicSSEParser.parse(line: error) == .error("Overloaded"), "anthropic: stream errors surface the message")

    let body = #"{"type":"error","error":{"type":"authentication_error","message":"invalid x-api-key"}}"#
    expect(AnthropicSSEParser.errorMessage(fromBody: body) == "invalid x-api-key", "anthropic: HTTP error body message extraction")
    expect(AnthropicSSEParser.errorMessage(fromBody: "<html>502</html>") == nil, "anthropic: non-JSON error body returns nil")
}

// MARK: - OpenAIChunkParser

do {
    let delta = #"data: {"id":"c1","choices":[{"delta":{"content":"Hey"},"index":0}]}"#
    expect(OpenAIChunkParser.parse(line: delta) == .textDelta("Hey"), "openai: content delta yields textDelta")

    expect(OpenAIChunkParser.parse(line: "data: [DONE]") == .done, "openai: [DONE] terminates")
    expect(OpenAIChunkParser.parse(line: "data:[DONE]") == .done, "openai: [DONE] without space terminates")

    let roleOnly = #"data: {"choices":[{"delta":{"role":"assistant"},"index":0}]}"#
    expect(OpenAIChunkParser.parse(line: roleOnly) == nil, "openai: role-only chunk is ignored")

    let emptyContent = #"data: {"choices":[{"delta":{"content":""},"index":0}]}"#
    expect(OpenAIChunkParser.parse(line: emptyContent) == nil, "openai: empty content is ignored")

    expect(OpenAIChunkParser.parse(line: ": ping") == nil, "openai: SSE comments are ignored")
}

// MARK: - BackendKind

do {
    expect(BackendKind(rawValue: "claude-code") == .claudeCode, "backend kinds: claude-code raw value round-trips")
    expect(BackendKind.allCases.count == 4, "backend kinds: four backends registered")
    expect(Set(BackendKind.allCases.map(\.displayName)).count == 4, "backend kinds: display names are unique")
}

// MARK: - Summary

if failures.isEmpty {
    print("All \(passed) tests passed.")
    exit(0)
} else {
    print("\(passed) passed, \(failures.count) FAILED")
    exit(1)
}
