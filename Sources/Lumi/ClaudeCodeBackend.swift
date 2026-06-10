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
                onEvent(.failed("Claude Code CLI not found. Install it (npm install -g @anthropic-ai/claude-code) or set LUMI_CLAUDE_PATH."))
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

        var lineBuffer = LineBuffer()
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

        stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
            let chunk = handle.availableData
            guard !chunk.isEmpty else { return }

            self.queue.async {
                for line in lineBuffer.append(chunk) {
                    guard let event = ClaudeCodeStreamParser.parse(line: line) else { continue }

                    switch event {
                    case .sessionStarted(let id):
                        sessionId = id
                        if existingSessionId == nil {
                            onEvent(.sessionStarted(id: id))
                        }
                        onEvent(.status("Claude Code is thinking..."))

                    case .textDelta(let text):
                        streamedText += text
                        onEvent(.delta(text))

                    case .success(let resultSessionId, let finalText):
                        finish(.completed(
                            sessionId: resultSessionId ?? sessionId,
                            finalMessage: finalText.isEmpty ? streamedText : finalText
                        ))
                        return

                    case .failure(let message):
                        finish(.failed(message))
                        return
                    }
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
