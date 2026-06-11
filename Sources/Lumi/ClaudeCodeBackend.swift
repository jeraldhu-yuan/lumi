import Foundation

/// Drives Claude Code as a single long-lived process per master session.
///
/// The CLI is launched once in bidirectional `stream-json` mode; each prompt is
/// a user message written to stdin and the same in-process session continues,
/// so follow-ups skip the cold start of a fresh `claude -p` per turn. Running
/// as the `--permission-prompt-tool` lets tool-use permission checks route into
/// Lumi's Allow/Deny dialog instead of a blanket policy.
final class ClaudeCodeBackend: AgentBackend {
    let kind: BackendKind = .claudeCode
    let capabilities = BackendCapabilities(
        usesWorkspace: true,
        supportsApprovals: true,
        canOpenCompanionApp: false,
        supervisorSummary: "Claude coordinator - native subagents, goals, memory",
        nativeFeatures: ["subagents", "background agents", "/goal", "/compact", "/fork", "/loop", "/batch", "auto-memory"]
    )

    private let queue = DispatchQueue(label: "ClaudeCodeBackend")

    private var process: Process?
    private var stdin: FileHandle?
    private var lineBuffer = LineBuffer()
    private var stderrBuffer = Data()
    private var resumedSessionID: String?

    // Per-turn state. Only one turn is in flight at a time.
    private var turn: Turn?

    private struct Turn {
        let onEvent: (AgentEvent) -> Void
        let workspacePath: String
        var streamedText = ""
        var sessionID: String?
        var sawInit = false
        var finished = false
    }

    func submit(
        request: AgentRequest,
        workspacePath: String,
        existingSessionId: String?,
        onEvent: @escaping (AgentEvent) -> Void
    ) {
        queue.async { [weak self] in
            guard let self else { return }

            if self.turn != nil {
                onEvent(.failed("Claude Code is already working on a request."))
                return
            }

            guard AppConfig.claudeExecutablePath != nil else {
                onEvent(.failed("Claude Code CLI not found. Install it (npm install -g @anthropic-ai/claude-code) or set LUMI_CLAUDE_PATH."))
                return
            }

            self.turn = Turn(onEvent: onEvent, workspacePath: workspacePath, sessionID: existingSessionId)
            self.startProcessIfNeeded(workspacePath: workspacePath, existingSessionId: existingSessionId)
            self.send(self.userMessage(for: request))
            onEvent(.status(self.process != nil ? "Lumi is thinking..." : "Starting Claude Code..."))
        }
    }

    func cancel() {
        queue.async { [weak self] in
            guard let self, var turn = self.turn, !turn.finished else { return }
            turn.finished = true
            self.turn = nil
            // Tearing down the process ends the turn cleanly; the next submit
            // resumes the persisted session in a fresh process.
            self.teardownProcess()
            turn.onEvent(.failed("Stopped."))
        }
    }

    func reset() {
        queue.async { [weak self] in
            self?.turn = nil
            self?.resumedSessionID = nil
            self?.teardownProcess()
        }
    }

    // MARK: - Process lifecycle

    private func startProcessIfNeeded(workspacePath: String, existingSessionId: String?) {
        // Reuse a live process only if it is the same persisted session.
        if let process, process.isRunning, resumedSessionID == existingSessionId {
            return
        }
        teardownProcess()

        guard let executable = AppConfig.claudeExecutablePath else { return }

        let process = Process()
        let stdinPipe = Pipe()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        var arguments = [
            "-p",
            "--input-format", "stream-json",
            "--output-format", "stream-json",
            "--verbose",
            "--include-partial-messages",
            "--permission-mode", AppConfig.claudePermissionMode,
            "--permission-prompt-tool", "stdio",
            "--append-system-prompt", AppConfig.supervisorInstructions(for: .claudeCode)
        ]
        if let existingSessionId, !existingSessionId.isEmpty {
            arguments += ["--resume", existingSessionId]
        } else {
            arguments += ["--name", "Lumi Master"]
        }

        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.currentDirectoryURL = URL(fileURLWithPath: workspacePath)
        process.standardInput = stdinPipe
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        lineBuffer = LineBuffer()
        stderrBuffer = Data()

        stdoutPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let chunk = handle.availableData
            guard !chunk.isEmpty else { return }
            self?.queue.async { self?.handleStdout(chunk) }
        }
        stderrPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let chunk = handle.availableData
            guard !chunk.isEmpty else { return }
            self?.queue.async { self?.stderrBuffer.append(chunk) }
        }
        process.terminationHandler = { [weak self] _ in
            self?.queue.async { self?.handleTermination() }
        }

        do {
            try process.run()
        } catch {
            turn?.onEvent(.failed("Could not launch Claude Code: \(error.localizedDescription)"))
            turn = nil
            return
        }

        self.process = process
        self.stdin = stdinPipe.fileHandleForWriting
        self.resumedSessionID = (existingSessionId?.isEmpty == false) ? existingSessionId : nil
    }

    private func teardownProcess() {
        if let process, process.isRunning {
            (process.standardOutput as? Pipe)?.fileHandleForReading.readabilityHandler = nil
            (process.standardError as? Pipe)?.fileHandleForReading.readabilityHandler = nil
            process.terminationHandler = nil
            try? stdin?.close()
            process.terminate()
        }
        process = nil
        stdin = nil
    }

    // MARK: - Stdout handling

    private func handleStdout(_ chunk: Data) {
        for line in lineBuffer.append(chunk) {
            guard let message = try? JSONSerialization.jsonObject(with: line) as? [String: Any] else { continue }

            if let permission = ClaudeCodeStreamParser.permissionRequest(message: message) {
                handlePermission(permission, rawRequest: (message["request"] as? [String: Any])?["input"] as? [String: Any])
                continue
            }

            guard let event = ClaudeCodeStreamParser.parse(message: message) else { continue }
            guard turn != nil else { continue }

            switch event {
            case .sessionStarted(let id):
                turn?.sawInit = true
                if turn?.sessionID == nil { turn?.onEvent(.sessionStarted(id: id)) }
                turn?.sessionID = id

            case .textDelta(let text):
                turn?.streamedText += text
                turn?.onEvent(.delta(text))

            case .toolActivity(let summary):
                turn?.onEvent(.activity(summary))

            case .success(let sessionID, let finalText):
                let resolved = sessionID ?? turn?.sessionID
                if let resolved { resumedSessionID = resolved }
                let message = finalText.isEmpty ? (turn?.streamedText ?? "") : finalText
                finishTurn(.completed(sessionId: resolved, finalMessage: message))

            case .failure(let message):
                failTurn(message)
            }
        }
    }

    private func handlePermission(_ permission: ClaudePermissionRequest, rawRequest input: [String: Any]?) {
        guard turn != nil else { return }

        let reply: (Bool) -> Void = { [weak self] approved in
            self?.queue.async {
                let decision: [String: Any] = approved
                    ? ["behavior": "allow", "updatedInput": input ?? [:]]
                    : ["behavior": "deny", "message": "Denied by the user."]
                let response: [String: Any] = [
                    "subtype": "success",
                    "request_id": permission.requestId,
                    "response": decision
                ]
                self?.send(["type": "control_response", "response": response])
            }
        }

        if AppConfig.codexAutoApprove {
            turn?.onEvent(.status("Auto-approving: \(permission.summary)"))
            reply(true)
            return
        }

        turn?.onEvent(.approvalRequest(description: permission.summary, respond: reply))
    }

    private func handleTermination() {
        guard var current = turn, !current.finished else {
            process = nil
            stdin = nil
            return
        }
        current.finished = true
        turn = nil
        let stderr = String(data: stderrBuffer, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)

        // A resume that dies before the stream initializes usually means the
        // stored session is gone — retry once on a fresh session.
        if !current.sawInit, resumedSessionID != nil || current.sessionID != nil {
            resumedSessionID = nil
            teardownProcess()
            current.onEvent(.status("Stored Claude Code session is unavailable. Starting fresh..."))
            // The caller's request is gone here; surface a soft failure so the
            // user can resend into the now-cleared session.
            current.onEvent(.failed("Couldn't resume the previous session. Send your request again to start fresh."))
            return
        }

        teardownProcess()
        current.onEvent(.failed(stderr?.isEmpty == false ? stderr! : "Claude Code exited before the turn completed."))
    }

    private func finishTurn(_ event: AgentEvent) {
        guard var current = turn, !current.finished else { return }
        current.finished = true
        turn = nil
        current.onEvent(event)
    }

    private func failTurn(_ message: String) {
        finishTurn(.failed(message))
    }

    // MARK: - Stdin

    private func userMessage(for request: AgentRequest) -> [String: Any] {
        [
            "type": "user",
            "message": [
                "role": "user",
                "content": [["type": "text", "text": request.promptForPathAwareBackend]]
            ]
        ]
    }

    private func send(_ message: [String: Any]) {
        guard let stdin,
              let data = try? JSONSerialization.data(withJSONObject: message) else { return }
        stdin.write(data)
        stdin.write(Data([0x0A]))
    }
}
