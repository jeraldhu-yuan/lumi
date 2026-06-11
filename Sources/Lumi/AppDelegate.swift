import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var spriteController: SpriteWindowController?
    private var promptController: PromptWindowController?
    private var backend: AgentBackend = BackendFactory.make(AppConfig.backendKind)
    private var isSending = false
    private var activeSessionId: String?
    private var responseTranscript = ""
    private var currentResponse = ""

    private var backendName: String { backend.kind.displayName }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let promptController = PromptWindowController(
            onSubmit: { [weak self] prompt in
                self?.submit(prompt: prompt)
            },
            onCancel: { [weak self] in
                self?.backend.cancel()
            },
            onOpenCompanionApp: {
                Self.openCodexApp()
            },
            onQuit: {
                NSApp.terminate(nil)
            },
            onNewThread: { [weak self] in
                self?.startNewSession()
            },
            onBackendChange: { [weak self] kind in
                self?.switchBackend(to: kind)
            },
            onTextChange: { [weak self] text in
                self?.promptTextChanged(text)
            },
            onClose: { [weak self] in
                self?.promptClosed()
            }
        )

        let spriteController = SpriteWindowController { [weak self, weak promptController] in
            guard let self, let promptController, let spriteFrame = self.spriteController?.window.frame else { return }
            promptController.show(near: spriteFrame)
            promptController.focusPrompt()
            self.facePrompt()
            self.spriteController?.setMood(.listening)
            promptController.update(
                status: self.activeSessionId == nil
                    ? "Ready for a new \(self.backendName) session."
                    : "Active session. Send a follow-up.",
                isSending: self.isSending,
                threadId: self.activeSessionId
            )
        }

        self.promptController = promptController
        self.spriteController = spriteController

        promptController.configure(for: backend)
        spriteController.show()
        promptController.update(
            status: backend.capabilities.usesWorkspace
                ? "Ready in \(URL(fileURLWithPath: AppConfig.workspacePath).lastPathComponent)"
                : "Ready to chat with \(backendName).",
            isSending: false,
            threadId: nil
        )
    }

    private func submit(prompt: String) {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            facePrompt()
            spriteController?.setMood(.listening)
            promptController?.update(status: "Type a request first.", isSending: false, threadId: nil)
            return
        }

        let continuingSessionId = activeSessionId
        if continuingSessionId == nil {
            activeSessionId = nil
            responseTranscript = ""
            promptController?.clearResponse()
        }

        isSending = true
        beginTranscriptTurn(prompt: trimmed)
        facePrompt()
        spriteController?.setMood(.working)
        promptController?.update(
            status: continuingSessionId == nil
                ? "Starting \(backendName) session..."
                : "Continuing \(backendName) session...",
            isSending: true,
            threadId: continuingSessionId
        )

        backend.submit(
            prompt: trimmed,
            workspacePath: AppConfig.workspacePath,
            existingSessionId: continuingSessionId
        ) { [weak self] event in
            Task { @MainActor in
                guard let self else { return }

                switch event {
                case .status(let message):
                    self.spriteController?.setMood(.working)
                    self.promptController?.update(status: message, isSending: true, threadId: self.activeSessionId ?? continuingSessionId)

                case .sessionStarted(let sessionId):
                    self.activeSessionId = sessionId
                    self.spriteController?.setMood(.working)
                    self.promptController?.update(
                        status: "\(self.backendName) is thinking...",
                        isSending: true,
                        threadId: sessionId
                    )

                case .delta(let delta):
                    self.appendResponseDelta(delta)
                    self.spriteController?.setMood(.threadActive)

                case .approvalRequest(let description, let respond):
                    self.spriteController?.setMood(.asking)
                    self.promptController?.update(
                        status: "Waiting for your approval...",
                        isSending: true,
                        threadId: self.activeSessionId ?? continuingSessionId
                    )
                    self.presentApproval(description: description, respond: respond)

                case .completed(let sessionId, let finalMessage):
                    self.isSending = false
                    self.activeSessionId = sessionId ?? self.activeSessionId
                    self.finishResponse(finalMessage: finalMessage)
                    self.promptController?.clearPrompt()
                    self.spriteController?.setMood(.threadActive)
                    self.promptController?.update(
                        status: "Ready. Send a follow-up whenever.",
                        isSending: false,
                        threadId: self.activeSessionId
                    )

                case .failed(let message):
                    self.isSending = false
                    self.appendSystemLine("Error: \(message)")
                    self.spriteController?.setMood(.failed)
                    self.promptController?.update(status: message, isSending: false, threadId: self.activeSessionId)
                }
            }
        }
    }

    private func presentApproval(description: String, respond: @escaping (Bool) -> Void) {
        guard let promptController else {
            respond(false)
            return
        }

        if let spriteFrame = spriteController?.window.frame {
            promptController.show(near: spriteFrame)
        }

        let alert = NSAlert()
        alert.messageText = "\(backendName) is asking to:"
        alert.informativeText = description
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Allow")
        alert.addButton(withTitle: "Deny")

        alert.beginSheetModal(for: promptController.window) { [weak self] response in
            let approved = response == .alertFirstButtonReturn
            respond(approved)
            Task { @MainActor in
                guard let self else { return }
                self.spriteController?.setMood(.working)
                self.promptController?.update(
                    status: approved ? "Approved. \(self.backendName) is working..." : "Denied. Waiting for \(self.backendName)...",
                    isSending: true,
                    threadId: self.activeSessionId
                )
            }
        }
    }

    private func switchBackend(to kind: BackendKind) {
        guard kind != backend.kind else { return }

        guard !isSending else {
            promptController?.configure(for: backend)
            promptController?.update(
                status: "Stop the current request before switching backends.",
                isSending: true,
                threadId: activeSessionId
            )
            return
        }

        AppConfig.setBackendKind(kind)
        backend = BackendFactory.make(kind)
        activeSessionId = nil
        responseTranscript = ""
        currentResponse = ""
        promptController?.clearResponse()
        promptController?.clearPrompt()
        promptController?.configure(for: backend)
        promptController?.update(
            status: "Switched to \(backendName). Ready for a new session.",
            isSending: false,
            threadId: nil
        )
        spriteController?.setMood(.listening)
    }

    private func promptTextChanged(_ text: String) {
        guard !isSending else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        facePrompt()
        spriteController?.setMood(trimmed.isEmpty ? .listening : .reading)
    }

    private func promptClosed() {
        guard !isSending else { return }
        spriteController?.setMood(activeSessionId == nil ? .idle : .threadActive)
    }

    private func startNewSession() {
        guard !isSending else { return }
        activeSessionId = nil
        responseTranscript = ""
        currentResponse = ""
        backend.reset()
        promptController?.clearResponse()
        promptController?.clearPrompt()
        promptController?.update(status: "Ready for a new \(backendName) session.", isSending: false, threadId: nil)
        spriteController?.setMood(.listening)
    }

    private func beginTranscriptTurn(prompt: String) {
        currentResponse = ""
        let separator = responseTranscript.isEmpty ? "" : "\n\n"
        responseTranscript += "\(separator)You: \(prompt)\n\n\(backendName): "
        promptController?.setResponse(responseTranscript)
    }

    private func appendResponseDelta(_ delta: String) {
        currentResponse += delta
        responseTranscript += delta
        promptController?.appendResponse(delta)
    }

    private func finishResponse(finalMessage: String) {
        let trimmedCurrent = currentResponse.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedFinal = finalMessage.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedCurrent.isEmpty && !trimmedFinal.isEmpty {
            responseTranscript += trimmedFinal
            promptController?.appendResponse(trimmedFinal)
        }
        currentResponse = ""
    }

    private func appendSystemLine(_ text: String) {
        let separator = responseTranscript.isEmpty ? "" : "\n\n"
        responseTranscript += "\(separator)\(text)"
        promptController?.setResponse(responseTranscript)
    }

    private func facePrompt() {
        guard let promptFrame = promptController?.window.frame else { return }
        spriteController?.face(point: NSPoint(x: promptFrame.midX, y: promptFrame.midY))
    }

    private static func openCodexApp() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: AppConfig.codexExecutablePath)
        process.arguments = ["app", AppConfig.workspacePath]

        do {
            try process.run()
        } catch {
            NSWorkspace.shared.open(URL(fileURLWithPath: "/Applications/Codex.app"))
        }
    }
}
