import Foundation

final class ClaudeCodeBackend: AgentBackend {
    let kind: BackendKind = .claudeCode
    let capabilities = BackendCapabilities(
        usesWorkspace: true,
        supportsApprovals: false,
        canOpenCompanionApp: false
    )

    private let queue = DispatchQueue(label: "ClaudeCodeBackend")
    private var activeProcess: Process?

    func submit(
        prompt: String,
        workspacePath: String,
        existingSessionId: String?,
        onEvent: @escaping (AgentEvent) -> Void
    ) {
        queue.async { [weak self] in
            guard let self else { return }

            if self.activeProcess != nil {
                onEvent(.failed("Claude Code is already working on a request."))
                return
            }

            guard let executable = AppConfig.claudeExecutablePath else {
                onEvent(.failed("Claude Code CLI not found. Install it (npm install -g @anthropic-ai/claude-code) or set CLAUDE_SPRITE_CLAUDE_PATH."))
                return
            }

            self.run(
                executable: executable,
                prompt: prompt,
                workspacePath: workspacePath,
                existingSessionId: existingSessionId,
                onEvent: onEvent
            )
        }
    }

    func cancel() {
        queue.async { [weak self] in
            self?.activeProcess?.terminate()
        }
    }

    func reset() {}

    private func run(
        executable: String,
        prompt: String,
        workspacePath: String,
        existingSessionId: String?,
        onEvent: @escaping (AgentEvent) -> Void
    ) {
        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        var arguments = [
            "-p", prompt,
            "--output-format", "stream-json",
            "--verbose",
            "--include-partial-messages",
            "--permission-mode", AppConfig.claudePermissionMode
        ]
        if let existingSessionId, !existingSessionId.isEmpty {
            arguments += ["--resume", existingSessionId]
        }

        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.currentDirectoryURL = URL(fileURLWithPath: workspacePath)
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        activeProcess = process

        var stdoutBuffer = Data()
        var stderrBuffer = Data()
        var sessionId = existingSessionId
        var streamedText = ""
        var completed = false

        func finish(_ event: AgentEvent) {
            guard !completed else { return }
            completed = true
            onEvent(event)
            stdoutPipe.fileHandleForReading.readabilityHandler = nil
            stderrPipe.fileHandleForReading.readabilityHandler = nil
            if process.isRunning {
                process.terminate()
            }
            activeProcess = nil
        }

        func processMessage(_ message: [String: Any]) {
            let type = message["type"] as? String

            switch type {
            case "system":
                if message["subtype"] as? String == "init",
                   let id = message["session_id"] as? String {
                    sessionId = id
                    if existingSessionId == nil {
                        onEvent(.sessionStarted(id: id))
                    }
                    onEvent(.status("Claude Code is thinking..."))
                }

            case "stream_event":
                guard let event = message["event"] as? [String: Any],
                      event["type"] as? String == "content_block_delta",
                      let delta = event["delta"] as? [String: Any],
                      delta["type"] as? String == "text_delta",
                      let text = delta["text"] as? String else { return }
                streamedText += text
                onEvent(.delta(text))

            case "result":
                let isError = message["is_error"] as? Bool ?? false
                let resultText = (message["result"] as? String) ?? streamedText
                if let id = message["session_id"] as? String {
                    sessionId = id
                }
                if isError {
                    finish(.failed(resultText.isEmpty ? "Claude Code turn failed." : resultText))
                } else {
                    finish(.completed(sessionId: sessionId, finalMessage: resultText))
                }

            default:
                break
            }
        }

        stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
            let chunk = handle.availableData
            guard !chunk.isEmpty else { return }

            self.queue.async {
                stdoutBuffer.append(chunk)

                while let newlineIndex = stdoutBuffer.firstIndex(of: 0x0A) {
                    let lineData = stdoutBuffer.subdata(in: stdoutBuffer.startIndex..<newlineIndex)
                    stdoutBuffer.removeSubrange(stdoutBuffer.startIndex...newlineIndex)

                    guard !lineData.isEmpty,
                          let message = try? JSONSerialization.jsonObject(with: lineData, options: []) as? [String: Any] else {
                        continue
                    }
                    processMessage(message)
                    if completed { return }
                }
            }
        }

        stderrPipe.fileHandleForReading.readabilityHandler = { handle in
            let chunk = handle.availableData
            guard !chunk.isEmpty else { return }
            self.queue.async {
                stderrBuffer.append(chunk)
            }
        }

        process.terminationHandler = { _ in
            self.queue.async {
                guard !completed else { return }
                let stderr = String(data: stderrBuffer, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                finish(.failed(stderr?.isEmpty == false ? stderr! : "Claude Code exited before the turn completed."))
            }
        }

        do {
            try process.run()
        } catch {
            activeProcess = nil
            onEvent(.failed("Could not launch Claude Code: \(error.localizedDescription)"))
            return
        }

        onEvent(.status(existingSessionId == nil ? "Starting Claude Code session..." : "Resuming Claude Code session..."))
    }
}
