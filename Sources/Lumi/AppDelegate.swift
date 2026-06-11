import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var spriteController: SpriteWindowController?
    private var promptController: PromptWindowController?
    private var backend: AgentBackend = BackendFactory.make(AppConfig.backendKind)
    private let sessionStore = MasterSessionStore()
    private var isSending = false
    private var activeSessionId: String?
    private var messages: [ConversationMessage] = []
    private var activeAssistantMessageIndex: Int?
    private let contextStore = LumiContextStore(workspacePath: AppConfig.workspacePath)

    private var backendName: String { backend.kind.displayName }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        AppMenu.install()
        _ = contextStore.ensureExists()
        activeSessionId = sessionStore.sessionID(for: backend.kind, workspacePath: AppConfig.workspacePath)

        let promptController = PromptWindowController(
            onSubmit: { [weak self] request in
                self?.submit(request: request)
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

        let spriteController = SpriteWindowController(
            onClick: { [weak self, weak promptController] in
                guard let self, promptController != nil else { return }
                self.showPrompt()
            },
            onAttachmentsDropped: { [weak self] attachments in
                self?.receiveDroppedAttachments(attachments)
            }
        )

        self.promptController = promptController
        self.spriteController = spriteController

        promptController.configure(for: backend)
        spriteController.show()
        promptController.update(
            status: "",
            isSending: false,
            threadId: activeSessionId
        )
        if AppConfig.openPromptOnLaunch {
            showPrompt()
        }
    }

    private func submit(request: AgentRequest) {
        guard !isSending else { return }

        let trimmed = request.prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty || !request.attachments.isEmpty else {
            facePrompt()
            spriteController?.setMood(.listening)
            promptController?.update(status: "Tell me what you need, or attach something.", isSending: false, threadId: activeSessionId)
            return
        }

        let normalizedRequest = AgentRequest(
            prompt: trimmed.isEmpty ? "Inspect the attached items and summarize what is relevant before deciding the next action." : trimmed,
            attachments: request.attachments
        )

        let continuingSessionId = activeSessionId
        if continuingSessionId == nil {
            activeSessionId = nil
            messages = []
            promptController?.clearMessages()
        }

        isSending = true
        beginConversationTurn(request: normalizedRequest)
        promptController?.clearPrompt()
        facePrompt()
        spriteController?.setMood(.working)
        promptController?.update(
            status: "On it...",
            isSending: true,
            threadId: continuingSessionId
        )

        backend.submit(
            request: normalizedRequest,
            workspacePath: AppConfig.workspacePath,
            existingSessionId: continuingSessionId
        ) { [weak self] event in
            Task { @MainActor in
                guard let self else { return }

                switch event {
                case .status(let message):
                    self.spriteController?.setMood(.working)
                    let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
                    self.promptController?.update(
                        status: trimmedMessage.isEmpty ? "Working..." : trimmedMessage,
                        isSending: true,
                        threadId: self.activeSessionId ?? continuingSessionId
                    )

                case .sessionStarted(let sessionId):
                    self.activeSessionId = sessionId
                    self.sessionStore.setSessionID(sessionId, for: self.backend.kind, workspacePath: AppConfig.workspacePath)
                    self.spriteController?.setMood(.working)
                    self.promptController?.update(
                        status: "Working...",
                        isSending: true,
                        threadId: sessionId
                    )

                case .delta(let delta):
                    self.appendResponseDelta(delta)
                    self.spriteController?.setMood(.threadActive)

                case .activity(let summary):
                    self.spriteController?.setMood(.working)
                    self.promptController?.update(
                        status: summary,
                        isSending: true,
                        threadId: self.activeSessionId ?? continuingSessionId
                    )

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
                    if let activeSessionId = self.activeSessionId {
                        self.sessionStore.setSessionID(activeSessionId, for: self.backend.kind, workspacePath: AppConfig.workspacePath)
                    }
                    self.finishResponse(finalMessage: finalMessage)
                    self.spriteController?.setMood(.threadActive)
                    self.promptController?.update(
                        status: "",
                        isSending: false,
                        threadId: self.activeSessionId
                    )

                case .failed(let message):
                    self.isSending = false
                    self.appendSystemLine("Error: \(message)")
                    self.spriteController?.setMood(.failed)
                    self.promptController?.update(status: "", isSending: false, threadId: self.activeSessionId)
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
                    status: approved ? "On it..." : "Okay, I won't do that.",
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
        activeSessionId = sessionStore.sessionID(for: kind, workspacePath: AppConfig.workspacePath)
        messages = []
        activeAssistantMessageIndex = nil
        promptController?.clearMessages()
        promptController?.clearPrompt()
        promptController?.configure(for: backend)
        promptController?.update(
            status: "",
            isSending: false,
            threadId: activeSessionId
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
        sessionStore.clearSession(for: backend.kind, workspacePath: AppConfig.workspacePath)
        activeSessionId = nil
        messages = []
        activeAssistantMessageIndex = nil
        backend.reset()
        promptController?.clearMessages()
        promptController?.clearPrompt()
        promptController?.update(status: "", isSending: false, threadId: nil)
        spriteController?.setMood(.listening)
    }

    private func beginConversationTurn(request: AgentRequest) {
        let attachmentLine = request.attachments.isEmpty
            ? ""
            : "\n\nAttachments: " + request.attachments.map(\.displayName).joined(separator: ", ")
        messages.append(ConversationMessage(role: .user, text: request.prompt + attachmentLine))
        messages.append(ConversationMessage(role: .assistant, text: ""))
        activeAssistantMessageIndex = messages.indices.last
        promptController?.setMessages(messages)
    }

    private func appendResponseDelta(_ delta: String) {
        guard let index = activeAssistantMessageIndex, messages.indices.contains(index) else { return }
        messages[index].text += delta
        promptController?.setMessages(messages)
    }

    private func finishResponse(finalMessage: String) {
        guard let index = activeAssistantMessageIndex, messages.indices.contains(index) else { return }
        let trimmedCurrent = messages[index].text.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedFinal = finalMessage.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedCurrent.isEmpty && !trimmedFinal.isEmpty {
            messages[index].text = trimmedFinal
        }
        activeAssistantMessageIndex = nil
        promptController?.setMessages(messages)
    }

    private func appendSystemLine(_ text: String) {
        if let index = activeAssistantMessageIndex,
           messages.indices.contains(index),
           messages[index].text.isEmpty {
            messages.remove(at: index)
        }
        activeAssistantMessageIndex = nil
        messages.append(ConversationMessage(role: .system, text: text))
        promptController?.setMessages(messages)
    }

    private func receiveDroppedAttachments(_ attachments: [AgentAttachment]) {
        guard !attachments.isEmpty, let promptController, let spriteController else { return }
        promptController.show(near: spriteController.window.frame)
        promptController.addAttachments(attachments)
        promptController.focusPrompt()
        promptController.update(
            status: "Got \(attachments.count == 1 ? "it" : "them"). What should I do with \(attachments.count == 1 ? "it" : "them")?",
            isSending: false,
            threadId: activeSessionId
        )
        spriteController.setMood(.success)
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(1.2))
            guard self?.isSending == false else { return }
            self?.spriteController?.setMood(.listening)
        }
    }

    private func showPrompt() {
        guard let promptController, let spriteFrame = spriteController?.window.frame else { return }
        promptController.show(near: spriteFrame)
        promptController.focusPrompt()
        facePrompt()
        spriteController?.setMood(.listening)
        promptController.update(
            status: isSending ? "Working..." : "",
            isSending: isSending,
            threadId: activeSessionId
        )
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
