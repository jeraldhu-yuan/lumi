import AppKit

@MainActor
final class PromptWindowController: NSObject {
    let window: NSPanel

    private let promptView: PromptView
    private let onSubmit: (String) -> Void
    private let onTextChange: (String) -> Void
    private let onClose: () -> Void

    init(
        onSubmit: @escaping (String) -> Void,
        onOpenCodex: @escaping () -> Void,
        onQuit: @escaping () -> Void,
        onNewThread: @escaping () -> Void,
        onTextChange: @escaping (String) -> Void,
        onClose: @escaping () -> Void
    ) {
        self.onSubmit = onSubmit
        self.onTextChange = onTextChange
        self.onClose = onClose
        promptView = PromptView(onOpenCodex: onOpenCodex, onQuit: onQuit, onNewThread: onNewThread)

        window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 370),
            styleMask: [.titled, .closable, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        window.title = "Ask Codex"
        window.isFloatingPanel = true
        window.level = .floating
        window.isReleasedWhenClosed = false
        window.hidesOnDeactivate = false
        window.contentView = promptView

        super.init()

        window.delegate = self
        promptView.onTextChange = { [weak self] text in
            self?.onTextChange(text)
        }
        promptView.onSubmit = { [weak self] prompt in
            self?.onSubmit(prompt)
        }
    }

    func show(near spriteFrame: NSRect) {
        if !window.isVisible {
            position(near: spriteFrame)
        }

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func focusPrompt() {
        promptView.focus()
    }

    func update(status: String, isSending: Bool, threadId: String?) {
        promptView.update(status: status, isSending: isSending, threadId: threadId)
    }

    func setResponse(_ text: String) {
        promptView.setResponse(text)
    }

    func appendResponse(_ text: String) {
        promptView.appendResponse(text)
    }

    func clearResponse() {
        promptView.clearResponse()
    }

    func clearPrompt() {
        promptView.clearPrompt()
    }

    private func position(near spriteFrame: NSRect) {
        guard let screen = window.screen ?? NSScreen.main else { return }
        let visible = screen.visibleFrame
        var frame = window.frame
        frame.origin.x = min(spriteFrame.minX - frame.width - 16, visible.maxX - frame.width - 16)
        frame.origin.y = min(max(spriteFrame.midY - frame.height / 2, visible.minY + 16), visible.maxY - frame.height - 16)

        if frame.origin.x < visible.minX + 16 {
            frame.origin.x = min(spriteFrame.maxX + 16, visible.maxX - frame.width - 16)
        }

        window.setFrame(frame, display: true)
    }
}

extension PromptWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        onClose()
    }
}

final class PromptView: NSVisualEffectView, NSTextViewDelegate {
    var onSubmit: ((String) -> Void)?
    var onTextChange: ((String) -> Void)?

    private let textView = NSTextView()
    private let responseTextView = NSTextView()
    private let statusLabel = NSTextField(labelWithString: "")
    private let threadLabel = NSTextField(labelWithString: "")
    private let sendButton = NSButton(title: "Send", target: nil, action: nil)
    private let newThreadButton = NSButton(title: "New Thread", target: nil, action: nil)
    private let openButton = NSButton(title: "Open Codex", target: nil, action: nil)
    private let quitButton = NSButton(title: "Quit", target: nil, action: nil)
    private let openSleeve: ClosureSleeve
    private let quitSleeve: ClosureSleeve
    private let newThreadSleeve: ClosureSleeve

    init(onOpenCodex: @escaping () -> Void, onQuit: @escaping () -> Void, onNewThread: @escaping () -> Void) {
        openSleeve = ClosureSleeve(onOpenCodex)
        quitSleeve = ClosureSleeve(onQuit)
        newThreadSleeve = ClosureSleeve(onNewThread)

        super.init(frame: .zero)
        material = .hudWindow
        blendingMode = .behindWindow
        state = .active

        let title = NSTextField(labelWithString: "Ask Codex")
        title.font = .systemFont(ofSize: 18, weight: .semibold)
        title.textColor = .labelColor

        let workspace = NSTextField(labelWithString: URL(fileURLWithPath: AppConfig.workspacePath).path)
        workspace.font = .systemFont(ofSize: 11)
        workspace.textColor = .secondaryLabelColor
        workspace.lineBreakMode = .byTruncatingMiddle

        let responseScrollView = NSScrollView()
        responseScrollView.hasVerticalScroller = true
        responseScrollView.borderType = .bezelBorder
        responseScrollView.documentView = responseTextView

        responseTextView.font = .systemFont(ofSize: 13)
        responseTextView.isRichText = false
        responseTextView.isEditable = false
        responseTextView.isSelectable = true
        responseTextView.drawsBackground = true
        responseTextView.backgroundColor = NSColor.textBackgroundColor.withAlphaComponent(0.72)
        responseTextView.textColor = .labelColor
        responseTextView.textContainerInset = NSSize(width: 8, height: 8)

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder
        scrollView.documentView = textView

        textView.font = .systemFont(ofSize: 14)
        textView.isRichText = false
        textView.allowsUndo = true
        textView.string = ""
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.delegate = self

        statusLabel.font = .systemFont(ofSize: 12)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.lineBreakMode = .byTruncatingTail

        threadLabel.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        threadLabel.textColor = .tertiaryLabelColor
        threadLabel.lineBreakMode = .byTruncatingMiddle

        sendButton.bezelStyle = .rounded
        sendButton.keyEquivalent = "\r"
        sendButton.keyEquivalentModifierMask = [.command]
        sendButton.target = self
        sendButton.action = #selector(send)

        openButton.bezelStyle = .rounded
        openButton.target = openSleeve
        openButton.action = #selector(ClosureSleeve.invoke)

        newThreadButton.bezelStyle = .rounded
        newThreadButton.target = newThreadSleeve
        newThreadButton.action = #selector(ClosureSleeve.invoke)

        quitButton.bezelStyle = .rounded
        quitButton.target = quitSleeve
        quitButton.action = #selector(ClosureSleeve.invoke)

        let buttonRow = NSStackView(views: [quitButton, NSView(), newThreadButton, openButton, sendButton])
        buttonRow.orientation = .horizontal
        buttonRow.spacing = 8
        buttonRow.alignment = .centerY
        buttonRow.distribution = .fill

        let stack = NSStackView(views: [title, workspace, responseScrollView, scrollView, statusLabel, threadLabel, buttonRow])
        stack.orientation = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -14),
            responseScrollView.heightAnchor.constraint(equalToConstant: 112),
            scrollView.heightAnchor.constraint(equalToConstant: 88),
            sendButton.widthAnchor.constraint(equalToConstant: 82),
            newThreadButton.widthAnchor.constraint(equalToConstant: 104),
            openButton.widthAnchor.constraint(equalToConstant: 108),
            quitButton.widthAnchor.constraint(equalToConstant: 72)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func focus() {
        window?.makeFirstResponder(textView)
    }

    func update(status: String, isSending: Bool, threadId: String?) {
        statusLabel.stringValue = status
        threadLabel.stringValue = threadId.map { "thread: \($0)" } ?? ""
        sendButton.isEnabled = !isSending
        newThreadButton.isEnabled = !isSending
        textView.isEditable = !isSending
    }

    func setResponse(_ text: String) {
        responseTextView.string = text
        scrollResponseToBottom()
    }

    func appendResponse(_ text: String) {
        responseTextView.string += text
        scrollResponseToBottom()
    }

    func clearResponse() {
        responseTextView.string = ""
    }

    func clearPrompt() {
        textView.string = ""
        onTextChange?("")
    }

    @objc private func send() {
        onSubmit?(textView.string)
    }

    func textDidChange(_ notification: Notification) {
        onTextChange?(textView.string)
    }

    private func scrollResponseToBottom() {
        let length = (responseTextView.string as NSString).length
        guard length > 0 else { return }
        responseTextView.scrollRangeToVisible(NSRange(location: length, length: 0))
    }
}

private final class ClosureSleeve: NSObject {
    private let closure: () -> Void

    init(_ closure: @escaping () -> Void) {
        self.closure = closure
    }

    @objc func invoke() {
        closure()
    }
}
