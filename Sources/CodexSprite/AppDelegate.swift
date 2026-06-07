import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var spriteController: SpriteWindowController?
    private var promptController: PromptWindowController?
    private let codexClient = CodexAppServerClient()
    private var isSending = false
    private var activeThreadId: String?
    private var responseTranscript = ""
    private var currentCodexResponse = ""

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let promptController = PromptWindowController(
            onSubmit: { [weak self] prompt in
                self?.submit(prompt: prompt)
            },
            onOpenCodex: {
                Self.openCodexApp()
            },
            onQuit: {
                NSApp.terminate(nil)
            },
            onNewThread: { [weak self] in
                self?.startNewThread()
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
                status: self.activeThreadId == nil ? "Ready for a new Codex thread." : "Active thread. Send a follow-up.",
                isSending: self.isSending,
                threadId: self.activeThreadId
            )
        }

        self.promptController = promptController
        self.spriteController = spriteController

        spriteController.show()
        promptController.update(
            status: "Ready in \(URL(fileURLWithPath: AppConfig.workspacePath).lastPathComponent)",
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

        let continuingThreadId = activeThreadId
        if continuingThreadId == nil {
            activeThreadId = nil
            responseTranscript = ""
            promptController?.clearResponse()
        }

        isSending = true
        beginTranscriptTurn(prompt: trimmed)
        facePrompt()
        spriteController?.setMood(.working)
        promptController?.update(
            status: continuingThreadId == nil ? "Starting Codex thread..." : "Continuing active Codex thread...",
            isSending: true,
            threadId: continuingThreadId
        )

        codexClient.submit(
            prompt: trimmed,
            workspacePath: AppConfig.workspacePath,
            existingThreadId: continuingThreadId
        ) { [weak self] event in
            Task { @MainActor in
                guard let self else { return }

                switch event {
                case .status(let message):
                    self.spriteController?.setMood(.working)
                    self.promptController?.update(status: message, isSending: true, threadId: self.activeThreadId ?? continuingThreadId)

                case .threadCreated(let threadId, _):
                    self.activeThreadId = threadId
                    self.spriteController?.setMood(.working)
                    self.promptController?.update(
                        status: "Codex is thinking...",
                        isSending: true,
                        threadId: threadId
                    )

                case .agentDelta(let delta):
                    self.appendCodexDelta(delta)
                    self.spriteController?.setMood(.threadActive)

                case .completed(let threadId, let finalMessage):
                    self.isSending = false
                    self.activeThreadId = threadId
                    self.finishCodexResponse(finalMessage: finalMessage)
                    self.promptController?.clearPrompt()
                    self.spriteController?.setMood(.threadActive)
                    self.promptController?.update(
                        status: "Ready. Send a follow-up whenever.",
                        isSending: false,
                        threadId: threadId
                    )

                case .failed(let message):
                    self.isSending = false
                    self.appendSystemLine("Error: \(message)")
                    self.spriteController?.setMood(.failed)
                    self.promptController?.update(status: message, isSending: false, threadId: self.activeThreadId)
                }
            }
        }
    }

    private func promptTextChanged(_ text: String) {
        guard !isSending else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        facePrompt()
        spriteController?.setMood(trimmed.isEmpty ? .listening : .reading)
    }

    private func promptClosed() {
        guard !isSending else { return }
        spriteController?.setMood(activeThreadId == nil ? .idle : .threadActive)
    }

    private func startNewThread() {
        guard !isSending else { return }
        activeThreadId = nil
        responseTranscript = ""
        currentCodexResponse = ""
        promptController?.clearResponse()
        promptController?.clearPrompt()
        promptController?.update(status: "Ready for a new Codex thread.", isSending: false, threadId: nil)
        spriteController?.setMood(.listening)
    }

    private func beginTranscriptTurn(prompt: String) {
        currentCodexResponse = ""
        let separator = responseTranscript.isEmpty ? "" : "\n\n"
        responseTranscript += "\(separator)You: \(prompt)\n\nCodex: "
        promptController?.setResponse(responseTranscript)
    }

    private func appendCodexDelta(_ delta: String) {
        currentCodexResponse += delta
        responseTranscript += delta
        promptController?.appendResponse(delta)
    }

    private func finishCodexResponse(finalMessage: String) {
        let trimmedCurrent = currentCodexResponse.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedFinal = finalMessage.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedCurrent.isEmpty && !trimmedFinal.isEmpty {
            responseTranscript += trimmedFinal
            promptController?.appendResponse(trimmedFinal)
        }
        currentCodexResponse = ""
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
