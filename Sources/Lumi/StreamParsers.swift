import Foundation

// Pure parsing for each backend's wire format. No I/O, no state — every
// function maps one line of stream output to a typed event, which keeps the
// protocol handling unit-testable without spawning processes or sockets.

// MARK: - Claude Code (`claude -p --input-format/--output-format stream-json`)

enum ClaudeCodeStreamEvent: Equatable {
    case sessionStarted(id: String)
    case textDelta(String)
    /// A complete tool-use block from an assistant message, summarized for the
    /// activity line ("Running: npm test", "Editing main.swift").
    case toolActivity(String)
    case success(sessionId: String?, finalText: String)
    case failure(String)
}

/// A `can_use_tool` control request from the CLI when Lumi runs as the
/// permission prompt tool. The backend echoes `requestId` back with a decision
/// and reuses the raw `input` for the `allow` response.
struct ClaudePermissionRequest: Equatable {
    let requestId: String
    let toolName: String
    let summary: String
}

enum ClaudeCodeStreamParser {
    static func parse(line: Data) -> ClaudeCodeStreamEvent? {
        guard let message = try? JSONSerialization.jsonObject(with: line) as? [String: Any] else {
            return nil
        }
        return parse(message: message)
    }

    static func parse(message: [String: Any]) -> ClaudeCodeStreamEvent? {
        switch message["type"] as? String {
        case "system":
            guard message["subtype"] as? String == "init",
                  let id = message["session_id"] as? String else { return nil }
            return .sessionStarted(id: id)

        case "stream_event":
            guard let event = message["event"] as? [String: Any],
                  event["type"] as? String == "content_block_delta",
                  let delta = event["delta"] as? [String: Any],
                  delta["type"] as? String == "text_delta",
                  let text = delta["text"] as? String else { return nil }
            return .textDelta(text)

        case "assistant":
            // Text streams via stream_event deltas; from the complete assistant
            // message we only surface tool-use activity.
            guard let content = (message["message"] as? [String: Any])?["content"] as? [[String: Any]] else {
                return nil
            }
            for block in content where block["type"] as? String == "tool_use" {
                if let name = block["name"] as? String {
                    return .toolActivity(toolSummary(name: name, input: block["input"] as? [String: Any]))
                }
            }
            return nil

        case "result":
            let isError = message["is_error"] as? Bool ?? false
            let sessionId = message["session_id"] as? String
            let text = message["result"] as? String ?? ""
            if isError {
                return .failure(text.isEmpty ? "Claude Code turn failed." : text)
            }
            return .success(sessionId: sessionId, finalText: text)

        default:
            return nil
        }
    }

    /// A `can_use_tool` control request, or nil for any other control message.
    static func permissionRequest(message: [String: Any]) -> ClaudePermissionRequest? {
        guard message["type"] as? String == "control_request",
              let requestId = message["request_id"] as? String,
              let request = message["request"] as? [String: Any],
              request["subtype"] as? String == "can_use_tool",
              let toolName = request["tool_name"] as? String else { return nil }

        let described = (request["description"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        let summary = described ?? toolSummary(name: toolName, input: request["input"] as? [String: Any])
        return ClaudePermissionRequest(requestId: requestId, toolName: toolName, summary: summary)
    }

    static func toolSummary(name: String, input: [String: Any]?) -> String {
        switch name {
        case "Bash":
            if let command = input?["command"] as? String {
                return "Run: \(command.prefix(80))"
            }
            return "Run a command"
        case "Edit", "Write", "NotebookEdit":
            if let path = input?["file_path"] as? String {
                return "\(name == "Write" ? "Write" : "Edit") \(URL(fileURLWithPath: path).lastPathComponent)"
            }
            return "\(name) a file"
        case "Read":
            if let path = input?["file_path"] as? String {
                return "Read \(URL(fileURLWithPath: path).lastPathComponent)"
            }
            return "Read a file"
        case "Grep", "Glob":
            if let pattern = input?["pattern"] as? String {
                return "Search \(pattern.prefix(40))"
            }
            return "Search the workspace"
        case "WebFetch", "WebSearch":
            return "Look something up online"
        case "Task":
            return "Delegate to a subagent"
        default:
            return "Use \(name)"
        }
    }
}
