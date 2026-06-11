import Foundation

final class ClaudeCodeBackend: AgentBackend {
    let kind: BackendKind = .claudeCode
    let capabilities = BackendCapabilities(
        usesWorkspace: true,
        supportsApprovals: false,
        canOpenCompanionApp: false,
        supervisorSummary: "Claude coordinator - native subagents, goals, memory",
        nativeFeatures: ["subagents", "background agents", "/goal", "/compact", "/fork", "/loop", "/batch", "auto-memory"]
    )

    private let queue = DispatchQueue(label: "ClaudeCodeBackend")
    private var activeProcess: Process?
    private var cancelRequested = false

    func submit(
        request: AgentRequest,
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

            self.cancelRequested = false
            self.run(
                executable: executable,
                request: request,
                workspacePath: workspacePath,
                existingSessionId: existingSessionId,
                onEvent: onEvent,
                allowSessionRecovery: true
            )
        }
    }

    func cancel() {
        queue.async { [weak self] in
            guard let self else { return }
            self.cancelRequested = true
            self.activeProcess?.terminate()
        }
    }

    func reset() {}

    private func run(
        executable: String,
        request: AgentRequest,
        workspacePath: String,
        existingSessionId: String?,
        onEvent: @escaping (AgentEvent) -> Void,
        allowSessionRecovery: Bool
    ) {
        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        var arguments = [
            "-p", request.promptForPathAwareBackend,
            "--output-format", "stream-json",
            "--verbose",
            "--include-partial-messages",
            "--permission-mode", AppConfig.claudePermissionMode,
            "--append-system-prompt", AppConfig.supervisorInstructions(for: .claudeCode)
        ]
        if let existingSessionId, !existingSessionId.isEmpty {
            arguments += ["--resume", existingSessionId]
        } else {
            arguments += ["--name", "Lumi Master"]
        }
        for directory in Set(request.attachments.map { $0.url.deletingLastPathComponent().path }).sorted() {
            arguments += ["--add-dir", directory]
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
        var sawInit = false

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

        // A persisted session can disappear out from under us (cleaned up by
        // the CLI, deleted by the user). When a resume dies before the stream
        // even initializes, retry once on a fresh session instead of failing.
        func failOrRecover(_ message: String) {
            guard !completed else { return }

            if !self.cancelRequested,
               allowSessionRecovery,
               !sawInit,
               let existingSessionId, !existingSessionId.isEmpty {
                completed = true
                stdoutPipe.fileHandleForReading.readabilityHandler = nil
                stderrPipe.fileHandleForReading.readabilityHandler = nil
                if process.isRunning {
                    process.terminate()
                }
                activeProcess = nil
                onEvent(.status("Stored Claude Code session is unavailable. Starting fresh..."))
                self.run(
                    executable: executable,
                    request: request,
                    workspacePath: workspacePath,
                    existingSessionId: nil,
                    onEvent: onEvent,
                    allowSessionRecovery: false
                )
                return
            }

            finish(.failed(self.cancelRequested ? "Stopped." : message))
        }

        stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
            let chunk = handle.availableData
            guard !chunk.isEmpty else { return }

            self.queue.async {
                for line in lineBuffer.append(chunk) {
                    guard let event = ClaudeCodeStreamParser.parse(line: line) else { continue }

                    switch event {
                    case .sessionStarted(let id):
                        sawInit = true
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
                        failOrRecover(message)
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
                failOrRecover(stderr?.isEmpty == false ? stderr! : "Claude Code exited before the turn completed.")
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
