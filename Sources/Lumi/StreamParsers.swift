import Foundation

// Pure parsing for each backend's wire format. No I/O, no state — every
// function maps one line of stream output to a typed event, which keeps the
// protocol handling unit-testable without spawning processes or sockets.

// MARK: - Claude Code (`claude -p --output-format stream-json`)

enum ClaudeCodeStreamEvent: Equatable {
    case sessionStarted(id: String)
    case textDelta(String)
    case success(sessionId: String?, finalText: String)
    case failure(String)
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
}

