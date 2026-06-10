import Foundation

// Pure parsing for each backend's wire format. No I/O, no state — every
// function maps one line of stream output to a typed event, which keeps the
// protocol handling unit-testable without spawning processes or sockets.

enum SSELine {
    /// Extracts the payload of an SSE `data:` line, tolerating both
    /// `data: {...}` and `data:{...}` framing. Returns nil for other fields.
    static func payload(_ line: String) -> Substring? {
        if line.hasPrefix("data: ") { return line.dropFirst(6) }
        if line.hasPrefix("data:") { return line.dropFirst(5) }
        return nil
    }
}

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

// MARK: - Anthropic Messages API (SSE)

enum AnthropicStreamEvent: Equatable {
    case textDelta(String)
    case messageStop
    case error(String)
}

enum AnthropicSSEParser {
    static func parse(line: String) -> AnthropicStreamEvent? {
        guard let payload = SSELine.payload(line),
              let data = payload.data(using: .utf8),
              let event = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = event["type"] as? String else { return nil }

        switch type {
        case "content_block_delta":
            guard let delta = event["delta"] as? [String: Any],
                  delta["type"] as? String == "text_delta",
                  let text = delta["text"] as? String else { return nil }
            return .textDelta(text)

        case "message_stop":
            return .messageStop

        case "error":
            let message = (event["error"] as? [String: Any])?["message"] as? String
            return .error(message ?? "Anthropic API stream error.")

        default:
            return nil
        }
    }

    static func errorMessage(fromBody body: String) -> String? {
        guard let data = body.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let error = json["error"] as? [String: Any],
              let message = error["message"] as? String else { return nil }
        return message
    }
}

// MARK: - OpenAI-compatible chat completions (SSE)

enum OpenAIStreamEvent: Equatable {
    case textDelta(String)
    case done
}

enum OpenAIChunkParser {
    static func parse(line: String) -> OpenAIStreamEvent? {
        guard let payload = SSELine.payload(line) else { return nil }
        if payload.trimmingCharacters(in: .whitespaces) == "[DONE]" { return .done }

        guard let data = payload.data(using: .utf8),
              let event = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = event["choices"] as? [[String: Any]],
              let delta = choices.first?["delta"] as? [String: Any],
              let text = delta["content"] as? String,
              !text.isEmpty else { return nil }
        return .textDelta(text)
    }
}
