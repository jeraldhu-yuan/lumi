import Foundation

final class CodexBackend: AgentBackend {
    let kind: BackendKind = .codex
    let capabilities = BackendCapabilities(
        usesWorkspace: true,
        supportsApprovals: true,
        canOpenCompanionApp: true
    )

    private let queue = DispatchQueue(label: "CodexBackend")
    private var activeProcess: Process?
    private var cancelAction: (() -> Void)?

    func submit(
        prompt: String,
        workspacePath: String,
        existingSessionId: String?,
        onEvent: @escaping (AgentEvent) -> Void
    ) {
        queue.async { [weak self] in
            guard let self else { return }

            if self.activeProcess != nil {
                onEvent(.failed("Codex is already working on a request."))
                return
            }

            self.run(prompt: prompt, workspacePath: workspacePath, existingThreadId: existingSessionId, onEvent: onEvent)
        }
    }

    func cancel() {
        queue.async { [weak self] in
            self?.cancelAction?()
        }
    }

    func reset() {}

    private func run(
        prompt: String,
        workspacePath: String,
        existingThreadId: String?,
        onEvent: @escaping (AgentEvent) -> Void
    ) {
        let process = Process()
        let stdinPipe = Pipe()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: AppConfig.codexExecutablePath)
        process.arguments = ["app-server", "--stdio"]
        process.currentDirectoryURL = URL(fileURLWithPath: workspacePath)
        process.standardInput = stdinPipe
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        activeProcess = process

        var stdoutBuffer = Data()
        var stderrBuffer = Data()
        var threadId = existingThreadId
        var finalMessage = ""
        var completed = false
        var lastTurnError: String?
        var sawTurnStarted = false

        func send(_ message: [String: Any]) {
            do {
                let data = try JSONSerialization.data(withJSONObject: message, options: [])
                stdinPipe.fileHandleForWriting.write(data)
                stdinPipe.fileHandleForWriting.write(Data([0x0A]))
            } catch {
                onEvent(.failed("Failed to encode Codex message: \(error.localizedDescription)"))
            }
        }

        func sendResponse(id: Any, result: [String: Any]) {
            send(["id": id, "result": result])
        }

        func sendError(id: Any, message: String) {
            send([
                "id": id,
                "error": [
                    "code": -32_001,
                    "message": message
                ]
            ])
        }

        func sendTurnStart(id: Int, threadId: String) {
            send([
                "method": "turn/start",
                "id": id,
                "params": [
                    "threadId": threadId,
                    "cwd": workspacePath,
                    "approvalPolicy": AppConfig.approvalPolicy,
                    "input": [
                        [
                            "type": "text",
                            "text": prompt,
                            "text_elements": []
                        ]
                    ]
                ]
            ])
        }

        func isNull(_ value: Any?) -> Bool {
            value == nil || value is NSNull
        }

        func turnErrorText(from value: Any?) -> String? {
            guard let error = value as? [String: Any] else { return nil }
            let message = error["message"] as? String
            let details = error["additionalDetails"] as? String
            let text = [message, details]
                .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: " ")
            return text.isEmpty ? nil : text
        }

        func requestApproval(
            description: String,
            onApprove: @escaping () -> Void,
            onDeny: @escaping () -> Void
        ) {
            if AppConfig.codexAutoApprove {
                onEvent(.status("Auto-approving: \(description)"))
                onApprove()
                return
            }

            onEvent(.approvalRequest(description: description) { [queue] approved in
                queue.async {
                    approved ? onApprove() : onDeny()
                }
            })
        }

        func handleServerRequest(method: String, id: Any, params: [String: Any]) -> Bool {
            switch method {
            case "item/commandExecution/requestApproval":
                let command = params["command"] as? String ?? "a shell command"
                requestApproval(
                    description: "Run command: \(command)",
                    onApprove: { sendResponse(id: id, result: ["decision": "acceptForSession"]) },
                    onDeny: { sendResponse(id: id, result: ["decision": "decline"]) }
                )
                return true

            case "item/fileChange/requestApproval":
                requestApproval(
                    description: "Apply file changes in the workspace",
                    onApprove: { sendResponse(id: id, result: ["decision": "acceptForSession"]) },
                    onDeny: { sendResponse(id: id, result: ["decision": "decline"]) }
                )
                return true

            case "item/permissions/requestApproval":
                let requested = params["permissions"] as? [String: Any] ?? [:]
                var granted: [String: Any] = [:]
                if let network = requested["network"], !isNull(network) {
                    granted["network"] = network
                }
                if let fileSystem = requested["fileSystem"], !isNull(fileSystem) {
                    granted["fileSystem"] = fileSystem
                }
                let names = granted.keys.sorted().joined(separator: ", ")
                requestApproval(
                    description: "Grant turn permissions: \(names.isEmpty ? "none" : names)",
                    onApprove: {
                        sendResponse(
                            id: id,
                            result: [
                                "permissions": granted,
                                "scope": "turn",
                                "strictAutoReview": false
                            ]
                        )
                    },
                    onDeny: {
                        sendResponse(
                            id: id,
                            result: [
                                "permissions": [:],
                                "scope": "turn",
                                "strictAutoReview": false
                            ]
                        )
                    }
                )
                return true

            case "execCommandApproval":
                requestApproval(
                    description: "Run a command (legacy request)",
                    onApprove: { sendResponse(id: id, result: ["decision": "approved_for_session"]) },
                    onDeny: { sendResponse(id: id, result: ["decision": "denied"]) }
                )
                return true

            case "applyPatchApproval":
                requestApproval(
                    description: "Apply a patch (legacy request)",
                    onApprove: { sendResponse(id: id, result: ["decision": "approved_for_session"]) },
                    onDeny: { sendResponse(id: id, result: ["decision": "denied"]) }
                )
                return true

            case "item/tool/requestUserInput":
                lastTurnError = "Codex requested interactive input that the sprite UI cannot answer yet."
                sendResponse(id: id, result: ["answers": [:]])
                return true

            case "mcpServer/elicitation/request":
                lastTurnError = "Codex requested an MCP elicitation that the sprite UI cannot answer yet."
                sendResponse(id: id, result: ["action": "decline", "content": NSNull(), "_meta": NSNull()])
                return true

            case "item/tool/call":
                let tool = params["tool"] as? String ?? "dynamic tool"
                lastTurnError = "Codex requested \(tool), but sprite dynamic tool calls are not wired yet."
                sendResponse(
                    id: id,
                    result: [
                        "success": false,
                        "contentItems": [
                            [
                                "type": "inputText",
                                "text": lastTurnError ?? "Unsupported sprite tool call."
                            ]
                        ]
                    ]
                )
                return true

            case "account/chatgptAuthTokens/refresh", "attestation/generate":
                sendError(id: id, message: "\(method) is not supported by Codex Sprite.")
                return true

            default:
                sendError(id: id, message: "Unsupported Codex app-server request: \(method)")
                return true
            }
        }

        func finish(_ event: AgentEvent) {
            guard !completed else { return }
            completed = true
            onEvent(event)
            stdoutPipe.fileHandleForReading.readabilityHandler = nil
            stderrPipe.fileHandleForReading.readabilityHandler = nil
            stdinPipe.fileHandleForWriting.closeFile()
            process.terminate()
            activeProcess = nil
            cancelAction = nil
        }

        func finishSuccessfulTurn() {
            let trimmedFinal = finalMessage.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedFinal.isEmpty, let lastTurnError {
                finish(.failed(lastTurnError))
                return
            }

            let message = trimmedFinal.isEmpty
                ? "Codex completed the turn. Open Codex to review details."
                : finalMessage
            finish(.completed(sessionId: threadId, finalMessage: message))
        }

        cancelAction = {
            finish(.failed("Stopped."))
        }

        stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
            let chunk = handle.availableData
            guard !chunk.isEmpty else { return }

            self.queue.async {
                stdoutBuffer.append(chunk)

                while let newlineIndex = stdoutBuffer.firstIndex(of: 0x0A) {
                    let lineData = stdoutBuffer.subdata(in: stdoutBuffer.startIndex..<newlineIndex)
                    stdoutBuffer.removeSubrange(stdoutBuffer.startIndex...newlineIndex)

                    guard !lineData.isEmpty else { continue }
                    guard let message = try? JSONSerialization.jsonObject(with: lineData, options: []) as? [String: Any] else {
                        continue
                    }

                    if let error = message["error"] as? [String: Any] {
                        let text = error["message"] as? String ?? "Codex app-server returned an error."
                        finish(.failed(text))
                        return
                    }

                    if (message["id"] as? Int) == 1 {
                        onEvent(.status("Connected to Codex app-server."))
                        send(["method": "initialized", "params": [:]])
                        if let existingThreadId, !existingThreadId.isEmpty {
                            onEvent(.status("Resuming active Codex thread..."))
                            send([
                                "method": "thread/resume",
                                "id": 2,
                                "params": [
                                    "threadId": existingThreadId,
                                    "cwd": workspacePath
                                ]
                            ])
                        } else {
                            send([
                                "method": "thread/start",
                                "id": 2,
                                "params": [
                                    "cwd": workspacePath,
                                    "sandbox": AppConfig.sandboxMode,
                                    "approvalPolicy": AppConfig.approvalPolicy,
                                    "threadSource": "user"
                                ]
                            ])
                        }
                        continue
                    }

                    if (message["id"] as? Int) == 2,
                       let result = message["result"] as? [String: Any],
                       let thread = result["thread"] as? [String: Any],
                       let readyThreadId = thread["id"] as? String {
                        threadId = readyThreadId
                        if existingThreadId == nil {
                            onEvent(.sessionStarted(id: readyThreadId))
                        } else {
                            onEvent(.status("Active thread resumed."))
                        }
                        sendTurnStart(id: 3, threadId: readyThreadId)
                        continue
                    }

                    if let method = message["method"] as? String {
                        if let requestId = message["id"],
                           let params = message["params"] as? [String: Any],
                           handleServerRequest(method: method, id: requestId, params: params) {
                            continue
                        }

                        switch method {
                        case "item/agentMessage/delta":
                            if let params = message["params"] as? [String: Any],
                               let delta = params["delta"] as? String {
                                finalMessage += delta
                                onEvent(.delta(delta))
                            }

                        case "item/completed":
                            if let params = message["params"] as? [String: Any],
                               let item = params["item"] as? [String: Any],
                               let type = item["type"] as? String,
                               type == "agentMessage",
                               finalMessage.isEmpty,
                               let text = item["text"] as? String {
                                finalMessage = text
                                if !text.isEmpty {
                                    onEvent(.delta(text))
                                }
                            }

                        case "turn/started":
                            sawTurnStarted = true

                        case "error":
                            if let params = message["params"] as? [String: Any],
                               let text = turnErrorText(from: params["error"]) {
                                lastTurnError = text
                                onEvent(.status("Codex error: \(text)"))
                            } else {
                                lastTurnError = "Codex app-server reported an error."
                                onEvent(.status(lastTurnError!))
                            }

                        case "thread/status/changed":
                            if let params = message["params"] as? [String: Any],
                               let status = params["status"] {
                                onEvent(.status("Codex status: \(status)"))
                                if sawTurnStarted,
                                   let statusInfo = status as? [String: Any],
                                   statusInfo["type"] as? String == "idle" {
                                    finishSuccessfulTurn()
                                    return
                                }
                            }

                        case "turn/completed":
                            if let params = message["params"] as? [String: Any],
                               let turn = params["turn"] as? [String: Any] {
                                let status = turn["status"] as? String
                                if let status, status != "completed" {
                                    let text = turnErrorText(from: turn["error"])
                                        ?? lastTurnError
                                        ?? "Codex turn ended with status \(status)."
                                    finish(.failed(text))
                                    return
                                }
                            }
                            finishSuccessfulTurn()
                            return

                        default:
                            break
                        }
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
                finish(.failed(stderr?.isEmpty == false ? stderr! : "Codex app-server exited before the turn completed."))
            }
        }

        do {
            try process.run()
        } catch {
            activeProcess = nil
            onEvent(.failed("Could not launch Codex: \(error.localizedDescription)"))
            return
        }

        onEvent(.status("Launching Codex app-server..."))
        send([
            "method": "initialize",
            "id": 1,
            "params": [
                "clientInfo": [
                    "name": "codex_sprite",
                    "title": "Codex Sprite",
                    "version": "0.2.0"
                ],
                "capabilities": [
                    "experimentalApi": true,
                    "requestAttestation": false
                ]
            ]
        ])
    }
}
