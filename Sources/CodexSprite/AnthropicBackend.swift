import Foundation

final class AnthropicBackend: AgentBackend {
    let kind: BackendKind = .anthropic
    let capabilities = BackendCapabilities(
        usesWorkspace: false,
        supportsApprovals: false,
        canOpenCompanionApp: false
    )

    private var history: [[String: Any]] = []
    private var sessionId: String?
    private var streamTask: Task<Void, Never>?

    func submit(
        prompt: String,
        workspacePath: String,
        existingSessionId: String?,
        onEvent: @escaping (AgentEvent) -> Void
    ) {
        guard streamTask == nil else {
            onEvent(.failed("Claude is already working on a request."))
            return
        }

        guard let apiKey = AppConfig.anthropicAPIKey, !apiKey.isEmpty else {
            onEvent(.failed("No Anthropic API key. Set the ANTHROPIC_API_KEY environment variable before launching."))
            return
        }

        let userMessage: [String: Any] = ["role": "user", "content": prompt]
        let requestMessages = history + [userMessage]

        var body: [String: Any] = [
            "model": AppConfig.anthropicModel,
            "max_tokens": 64000,
            "stream": true,
            "thinking": ["type": "adaptive"],
            "messages": requestMessages
        ]
        if let system = AppConfig.chatSystemPrompt {
            body["system"] = system
        }

        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [])

        if sessionId == nil {
            sessionId = UUID().uuidString
            onEvent(.sessionStarted(id: sessionId!))
        }
        let turnSessionId = sessionId

        onEvent(.status("Asking Claude (\(AppConfig.anthropicModel))..."))

        streamTask = Task { [weak self] in
            defer { self?.streamTask = nil }

            var assistantText = ""

            do {
                let (bytes, response) = try await URLSession.shared.bytes(for: request)

                if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                    var errorBody = ""
                    for try await line in bytes.lines {
                        errorBody += line
                    }
                    let message = Self.apiErrorMessage(from: errorBody) ?? "Anthropic API returned HTTP \(http.statusCode)."
                    onEvent(.failed(message))
                    return
                }

                for try await line in bytes.lines {
                    guard line.hasPrefix("data: "),
                          let data = line.dropFirst(6).data(using: .utf8),
                          let event = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                          let type = event["type"] as? String else { continue }

                    switch type {
                    case "content_block_delta":
                        if let delta = event["delta"] as? [String: Any],
                           delta["type"] as? String == "text_delta",
                           let text = delta["text"] as? String {
                            assistantText += text
                            onEvent(.delta(text))
                        }

                    case "error":
                        let message = (event["error"] as? [String: Any])?["message"] as? String
                        onEvent(.failed(message ?? "Anthropic API stream error."))
                        return

                    case "message_stop":
                        self?.history = requestMessages + [["role": "assistant", "content": assistantText]]
                        onEvent(.completed(sessionId: turnSessionId, finalMessage: assistantText))
                        return

                    default:
                        break
                    }
                }

                onEvent(.failed("Anthropic API stream ended unexpectedly."))
            } catch is CancellationError {
                onEvent(.failed("Stopped."))
            } catch {
                onEvent(.failed("Anthropic API request failed: \(error.localizedDescription)"))
            }
        }
    }

    func cancel() {
        streamTask?.cancel()
    }

    func reset() {
        history = []
        sessionId = nil
    }

    private static func apiErrorMessage(from body: String) -> String? {
        guard let data = body.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
              let error = json["error"] as? [String: Any],
              let message = error["message"] as? String else { return nil }
        return message
    }
}
