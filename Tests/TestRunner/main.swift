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

// MARK: - Requests and attachments

do {
    let image = AgentAttachment.from(url: URL(fileURLWithPath: "/tmp/example.png"))
    let document = AgentAttachment.from(url: URL(fileURLWithPath: "/tmp/notes.pdf"))
    let request = AgentRequest(prompt: "Review these", attachments: [image, document])
    let pastedImage = AgentAttachment(url: URL(fileURLWithPath: "/tmp/clipboard-id.png"), kind: .image, label: "Pasted image")
    expect(image.kind == .image, "attachments: image extension is classified")
    expect(document.kind == .file, "attachments: document extension is classified")
    expect(pastedImage.displayName == "Pasted image", "attachments: pasted images use a friendly label")
    expect(request.promptForPathAwareBackend.contains("/tmp/example.png"), "requests: attachment paths are included for CLI backends")
}

// MARK: - MasterSessionStore

do {
    let suiteName = "LumiTests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let store = MasterSessionStore(defaults: defaults)

    expect(store.sessionID(for: .codex, workspacePath: "/tmp/a") == nil, "master sessions: missing session returns nil")
    store.setSessionID("codex-1", for: .codex, workspacePath: "/tmp/a")
    store.setSessionID("claude-1", for: .claudeCode, workspacePath: "/tmp/a")
    expect(store.sessionID(for: .codex, workspacePath: "/tmp/a") == "codex-1", "master sessions: stores Codex session")
    expect(store.sessionID(for: .claudeCode, workspacePath: "/tmp/a") == "claude-1", "master sessions: separates providers")
    store.clearSession(for: .codex, workspacePath: "/tmp/a")
    expect(store.sessionID(for: .codex, workspacePath: "/tmp/a") == nil, "master sessions: clears one provider")
    expect(store.sessionID(for: .claudeCode, workspacePath: "/tmp/a") == "claude-1", "master sessions: preserves other providers")
}

// MARK: - LumiContextStore

do {
    let workspace = FileManager.default.temporaryDirectory
        .appendingPathComponent("LumiContextTests-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: workspace) }
    let store = LumiContextStore(workspacePath: workspace.path)

    let url = store.ensureExists()
    expect(FileManager.default.fileExists(atPath: url.path), "context: creates a workspace-local context file")
    expect(store.text().contains("# Lumi Context"), "context: reads the default context")
    try? "durable preference".write(to: url, atomically: true, encoding: .utf8)
    expect(store.text() == "durable preference", "context: preserves and reads refinements")
}

// MARK: - CodexSessionRecovery

do {
    var stale = CodexSessionRecovery(requestedSessionID: "missing-thread")
    expect(stale.shouldRetryWithFreshThread(responseID: 2), "codex recovery: failed resume starts a fresh thread")
    expect(stale.readyThreadIsNew, "codex recovery: replacement thread is persisted as new")
    expect(!stale.shouldRetryWithFreshThread(responseID: 2), "codex recovery: retries only once")

    var fresh = CodexSessionRecovery(requestedSessionID: nil)
    expect(!fresh.shouldRetryWithFreshThread(responseID: 2), "codex recovery: fresh thread errors are not retried as resume failures")
    expect(fresh.readyThreadIsNew, "codex recovery: initial thread is reported as new")

    var active = CodexSessionRecovery(requestedSessionID: "active-thread")
    expect(!active.shouldRetryWithFreshThread(responseID: 3), "codex recovery: turn failures do not reset the session")
    expect(!active.readyThreadIsNew, "codex recovery: successful resume stays active")
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
    expect(ClaudeCodeStreamParser.parse(line: data(#"{"type":"assistant","message":{"content":[{"type":"text","text":"hi"}]}}"#)) == nil, "claude-code: text-only assistant messages yield no activity")

    let toolUse = #"{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Bash","input":{"command":"npm test"}}]}}"#
    expect(ClaudeCodeStreamParser.parse(line: data(toolUse)) == .toolActivity("Run: npm test"), "claude-code: tool_use surfaces a Bash activity summary")

    let editUse = #"{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Edit","input":{"file_path":"/x/main.swift"}}]}}"#
    expect(ClaudeCodeStreamParser.parse(line: data(editUse)) == .toolActivity("Edit main.swift"), "claude-code: Edit tool_use names the file")
}

// MARK: - Claude permission control requests

do {
    let canUse = #"{"type":"control_request","request_id":"req-7","request":{"subtype":"can_use_tool","tool_name":"Write","input":{"file_path":"/x/notes.txt"}}}"#
    guard let dict = try? JSONSerialization.jsonObject(with: data(canUse)) as? [String: Any] else {
        expect(false, "claude permissions: control request parses as JSON")
        fatalError()
    }
    let parsed = ClaudeCodeStreamParser.permissionRequest(message: dict)
    expect(parsed?.requestId == "req-7", "claude permissions: request id extracted")
    expect(parsed?.toolName == "Write", "claude permissions: tool name extracted")
    expect(parsed?.summary == "Write notes.txt", "claude permissions: summary falls back to tool+path")

    let described = #"{"type":"control_request","request_id":"r2","request":{"subtype":"can_use_tool","tool_name":"Bash","description":"Allow network access?","input":{}}}"#
    let dict2 = try! JSONSerialization.jsonObject(with: data(described)) as! [String: Any]
    expect(ClaudeCodeStreamParser.permissionRequest(message: dict2)?.summary == "Allow network access?", "claude permissions: explicit description wins")

    let other = #"{"type":"control_request","request_id":"r3","request":{"subtype":"initialize"}}"#
    let dict3 = try! JSONSerialization.jsonObject(with: data(other)) as! [String: Any]
    expect(ClaudeCodeStreamParser.permissionRequest(message: dict3) == nil, "claude permissions: non-can_use_tool control requests are ignored")
}

// MARK: - Codex activity summaries

do {
    expect(CodexBackend.activitySummary(for: ["type": "commandExecution", "command": "ls -la"]) == "Run: ls -la", "codex activity: command execution")
    expect(CodexBackend.activitySummary(for: ["type": "fileChange"]) == "Editing files in the workspace", "codex activity: file change")
    expect(CodexBackend.activitySummary(for: ["type": "agentMessage"]) == nil, "codex activity: message items are not activity")
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
