import Foundation

final class OpenAICompatibleBackend: AgentBackend {
    let kind: BackendKind = .openAICompatible
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
            onEvent(.failed("The model is already working on a request."))
            return
        }

        guard let url = URL(string: AppConfig.openAIBaseURL)?.appendingPathComponent("chat/completions") else {
            onEvent(.failed("Invalid endpoint URL: \(AppConfig.openAIBaseURL)"))
            return
        }

        var requestMessages: [[String: Any]] = []
        if let system = AppConfig.chatSystemPrompt {
            requestMessages.append(["role": "system", "content": system])
        }
        requestMessages += history
        let userMessage: [String: Any] = ["role": "user", "content": prompt]
        requestMessages.append(userMessage)

        let body: [String: Any] = [
            "model": AppConfig.openAIModel,
            "stream": true,
            "messages": requestMessages
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let apiKey = AppConfig.openAIAPIKey, !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [])

        if sessionId == nil {
            sessionId = UUID().uuidString
            onEvent(.sessionStarted(id: sessionId!))
        }
        let turnSessionId = sessionId
        let priorHistory = history

        onEvent(.status("Asking \(AppConfig.openAIModel)..."))

        streamTask = Task { [weak self] in
            defer { self?.streamTask = nil }

            var assistantText = ""

            func finishTurn() {
                self?.history = priorHistory + [userMessage, ["role": "assistant", "content": assistantText]]
                onEvent(.completed(sessionId: turnSessionId, finalMessage: assistantText))
            }

            do {
                let (bytes, response) = try await URLSession.shared.bytes(for: request)

                if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                    var errorBody = ""
                    for try await line in bytes.lines {
                        errorBody += line
                    }
                    onEvent(.failed("Model endpoint returned HTTP \(http.statusCode): \(errorBody.prefix(300))"))
                    return
                }

                for try await line in bytes.lines {
                    guard line.hasPrefix("data: ") else { continue }
                    let payload = line.dropFirst(6)

                    if payload == "[DONE]" {
                        finishTurn()
                        return
                    }

                    guard let data = payload.data(using: .utf8),
                          let event = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                          let choices = event["choices"] as? [[String: Any]],
                          let choice = choices.first else { continue }

                    if let delta = choice["delta"] as? [String: Any],
                       let text = delta["content"] as? String,
                       !text.isEmpty {
                        assistantText += text
                        onEvent(.delta(text))
                    }
                }

                finishTurn()
            } catch is CancellationError {
                onEvent(.failed("Stopped."))
            } catch {
                onEvent(.failed("Could not reach \(AppConfig.openAIBaseURL): \(error.localizedDescription)"))
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
}
