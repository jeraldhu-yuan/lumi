import AppKit

@MainActor
final class PromptWindowController: NSObject {
    private static let compactHeight: CGFloat = 176
    private static let expandedHeight: CGFloat = 430

    let window: NSPanel

    private let promptView: PromptView
    private let onSubmit: (String) -> Void
    private let onTextChange: (String) -> Void
    private let onClose: () -> Void

    init(
        onSubmit: @escaping (String) -> Void,
        onCancel: @escaping () -> Void,
        onOpenCompanionApp: @escaping () -> Void,
        onQuit: @escaping () -> Void,
        onNewThread: @escaping () -> Void,
        onBackendChange: @escaping (BackendKind) -> Void,
        onTextChange: @escaping (String) -> Void,
        onClose: @escaping () -> Void
    ) {
        self.onSubmit = onSubmit
        self.onTextChange = onTextChange
        self.onClose = onClose
        promptView = PromptView(
            onCancel: onCancel,
            onOpenCompanionApp: onOpenCompanionApp,
            onQuit: onQuit,
            onNewThread: onNewThread,
            onBackendChange: onBackendChange
        )

        window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 430, height: Self.compactHeight),
            styleMask: [.titled, .closable, .utilityWindow, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Lumi"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
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
        promptView.onTranscriptVisibilityChange = { [weak self] expanded in
            self?.setExpanded(expanded)
        }
    }

    func configure(for backend: AgentBackend) {
        window.title = "Lumi — \(backend.kind.displayName)"
        promptView.configure(
            backendName: backend.kind.displayName,
            kind: backend.kind,
            showsCompanionApp: backend.capabilities.canOpenCompanionApp,
            showsWorkspace: backend.capabilities.usesWorkspace
        )
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

    private func setExpanded(_ expanded: Bool) {
        let target = expanded ? Self.expandedHeight : Self.compactHeight
        var frame = window.frame
        guard abs(frame.height - target) > 0.5 else { return }

        frame.origin.y += frame.height - target
        frame.size.height = target
        if let screen = window.screen ?? NSScreen.main {
            frame.origin.y = max(frame.origin.y, screen.visibleFrame.minY + 8)
        }
        window.setFrame(frame, display: true, animate: window.isVisible)
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
    var onTranscriptVisibilityChange: ((Bool) -> Void)?

    private let transcriptTextView = NSTextView()
    private let transcriptScroll = NSScrollView()
    private let inputTextView = NSTextView()
    private let titleLabel = NSTextField(labelWithString: "Lumi")
    private let workspaceLabel: NSTextField
    private let placeholderLabel = NSTextField(labelWithString: "Ask anything...")
    private let statusLabel = NSTextField(labelWithString: "")
    private let sendButton = NSButton()
    private let newSessionButton = NSButton()
    private let openAppButton = NSButton()
    private let quitButton = NSButton()
    private let backendPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let onCancel: () -> Void
    private let onBackendChange: (BackendKind) -> Void
    private let openSleeve: ClosureSleeve
    private let quitSleeve: ClosureSleeve
    private let newThreadSleeve: ClosureSleeve
    private var isSending = false

    init(
        onCancel: @escaping () -> Void,
        onOpenCompanionApp: @escaping () -> Void,
        onQuit: @escaping () -> Void,
        onNewThread: @escaping () -> Void,
        onBackendChange: @escaping (BackendKind) -> Void
    ) {
        self.onCancel = onCancel
        self.onBackendChange = onBackendChange
        openSleeve = ClosureSleeve(onOpenCompanionApp)
        quitSleeve = ClosureSleeve(onQuit)
        newThreadSleeve = ClosureSleeve(onNewThread)
        workspaceLabel = NSTextField(labelWithString: URL(fileURLWithPath: AppConfig.workspacePath).path)

        super.init(frame: .zero)
        material = .hudWindow
        blendingMode = .behindWindow
        state = .active

        titleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        titleLabel.textColor = .labelColor

        backendPopup.addItems(withTitles: BackendKind.allCases.map(\.displayName))
        backendPopup.controlSize = .small
        backendPopup.font = .systemFont(ofSize: 11, weight: .medium)
        backendPopup.target = self
        backendPopup.action = #selector(backendChanged)

        let titleRow = NSStackView(views: [titleLabel, NSView(), backendPopup])
        titleRow.orientation = .horizontal
        titleRow.spacing = 8
        titleRow.alignment = .centerY

        workspaceLabel.font = .systemFont(ofSize: 10)
        workspaceLabel.textColor = .tertiaryLabelColor
        workspaceLabel.lineBreakMode = .byTruncatingMiddle

        // The transcript floats directly on the window blur — no box. It is
        // hidden entirely until a conversation produces text, which keeps the
        // resting window a compact ask bar.
        transcriptScroll.hasVerticalScroller = true
        transcriptScroll.autohidesScrollers = true
        transcriptScroll.borderType = .noBorder
        transcriptScroll.drawsBackground = false
        transcriptScroll.documentView = transcriptTextView
        transcriptScroll.isHidden = true

        transcriptTextView.font = .systemFont(ofSize: 13)
        transcriptTextView.isRichText = false
        transcriptTextView.isEditable = false
        transcriptTextView.isSelectable = true
        transcriptTextView.drawsBackground = false
        transcriptTextView.textColor = .labelColor
        transcriptTextView.textContainerInset = NSSize(width: 4, height: 6)

        let inputScroll = Self.roundedScroll(for: inputTextView, backgroundAlpha: 0.55)
        inputTextView.font = .systemFont(ofSize: 13)
        inputTextView.isRichText = false
        inputTextView.allowsUndo = true
        inputTextView.drawsBackground = false
        inputTextView.string = ""
        inputTextView.textContainerInset = NSSize(width: 10, height: 9)
        inputTextView.delegate = self

        placeholderLabel.font = .systemFont(ofSize: 13)
        placeholderLabel.textColor = .placeholderTextColor
        placeholderLabel.lineBreakMode = .byTruncatingTail
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
        inputScroll.addSubview(placeholderLabel)

        Self.styleIconButton(sendButton, symbol: "arrow.up.circle.fill", pointSize: 26, tint: .controlAccentColor, tooltip: "Send (⌘↩)")
        sendButton.keyEquivalent = "\r"
        sendButton.keyEquivalentModifierMask = [.command]
        sendButton.target = self
        sendButton.action = #selector(send)

        let inputRow = NSStackView(views: [inputScroll, sendButton])
        inputRow.orientation = .horizontal
        inputRow.spacing = 8
        inputRow.alignment = .centerY

        statusLabel.font = .systemFont(ofSize: 11)
        statusLabel.textColor = .tertiaryLabelColor
        statusLabel.lineBreakMode = .byTruncatingTail
        statusLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        Self.styleIconButton(newSessionButton, symbol: "plus.bubble", pointSize: 14, tint: .secondaryLabelColor, tooltip: "New session")
        newSessionButton.target = newThreadSleeve
        newSessionButton.action = #selector(ClosureSleeve.invoke)

        Self.styleIconButton(openAppButton, symbol: "arrow.up.forward.app", pointSize: 14, tint: .secondaryLabelColor, tooltip: "Open Codex Desktop")
        openAppButton.target = openSleeve
        openAppButton.action = #selector(ClosureSleeve.invoke)

        Self.styleIconButton(quitButton, symbol: "power", pointSize: 14, tint: .secondaryLabelColor, tooltip: "Quit Lumi")
        quitButton.target = quitSleeve
        quitButton.action = #selector(ClosureSleeve.invoke)

        let footerRow = NSStackView(views: [statusLabel, NSView(), newSessionButton, openAppButton, quitButton])
        footerRow.orientation = .horizontal
        footerRow.spacing = 10
        footerRow.alignment = .centerY

        let stack = NSStackView(views: [titleRow, workspaceLabel, transcriptScroll, inputRow, footerRow])
        stack.orientation = .vertical
        stack.spacing = 10
        stack.setCustomSpacing(2, after: titleRow)
        stack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 28),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
            inputScroll.heightAnchor.constraint(equalToConstant: 52),
            sendButton.widthAnchor.constraint(equalToConstant: 34),
            placeholderLabel.leadingAnchor.constraint(equalTo: inputScroll.leadingAnchor, constant: 14),
            placeholderLabel.trailingAnchor.constraint(lessThanOrEqualTo: inputScroll.trailingAnchor, constant: -14),
            placeholderLabel.topAnchor.constraint(equalTo: inputScroll.topAnchor, constant: 10)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private static func roundedScroll(for textView: NSTextView, backgroundAlpha: CGFloat) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = true
        scrollView.backgroundColor = NSColor.textBackgroundColor.withAlphaComponent(backgroundAlpha)
        scrollView.documentView = textView
        scrollView.wantsLayer = true
        scrollView.layer?.cornerRadius = 12
        scrollView.layer?.masksToBounds = true
        return scrollView
    }

    private static func styleIconButton(_ button: NSButton, symbol: String, pointSize: CGFloat, tint: NSColor, tooltip: String) {
        let config = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .medium)
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: tooltip)?
            .withSymbolConfiguration(config)
        button.isBordered = false
        button.contentTintColor = tint
        button.toolTip = tooltip
        button.imagePosition = .imageOnly
        button.setButtonType(.momentaryChange)
    }

    func configure(backendName: String, kind: BackendKind, showsCompanionApp: Bool, showsWorkspace: Bool) {
        placeholderLabel.stringValue = "Ask \(backendName) anything..."
        openAppButton.isHidden = !showsCompanionApp
        workspaceLabel.isHidden = !showsWorkspace
        if let index = BackendKind.allCases.firstIndex(of: kind) {
            backendPopup.selectItem(at: index)
        }
    }

    func focus() {
        window?.makeFirstResponder(inputTextView)
    }

    func update(status: String, isSending: Bool, threadId: String?) {
        self.isSending = isSending
        statusLabel.stringValue = status
        statusLabel.toolTip = threadId.map { "Session: \($0)" }

        let symbol = isSending ? "stop.circle.fill" : "arrow.up.circle.fill"
        let config = NSImage.SymbolConfiguration(pointSize: 26, weight: .medium)
        sendButton.image = NSImage(systemSymbolName: symbol, accessibilityDescription: isSending ? "Stop" : "Send")?
            .withSymbolConfiguration(config)
        sendButton.toolTip = isSending ? "Stop" : "Send (⌘↩)"

        newSessionButton.isEnabled = !isSending
        backendPopup.isEnabled = !isSending
        inputTextView.isEditable = !isSending
        updatePlaceholderVisibility()
    }

    func setResponse(_ text: String) {
        transcriptTextView.string = text
        updateTranscriptVisibility()
        scrollTranscriptToBottom()
    }

    func appendResponse(_ text: String) {
        transcriptTextView.string += text
        updateTranscriptVisibility()
        scrollTranscriptToBottom()
    }

    func clearResponse() {
        transcriptTextView.string = ""
        updateTranscriptVisibility()
    }

    func clearPrompt() {
        inputTextView.string = ""
        updatePlaceholderVisibility()
        onTextChange?("")
    }

    @objc private func send() {
        if isSending {
            onCancel()
        } else {
            onSubmit?(inputTextView.string)
        }
    }

    @objc private func backendChanged() {
        let index = backendPopup.indexOfSelectedItem
        guard index >= 0, index < BackendKind.allCases.count else { return }
        onBackendChange(BackendKind.allCases[index])
    }

    func textDidChange(_ notification: Notification) {
        updatePlaceholderVisibility()
        onTextChange?(inputTextView.string)
    }

    private func updatePlaceholderVisibility() {
        placeholderLabel.isHidden = !inputTextView.string.isEmpty
    }

    private func updateTranscriptVisibility() {
        let hasContent = !transcriptTextView.string.isEmpty
        guard transcriptScroll.isHidden == hasContent else { return }
        transcriptScroll.isHidden = !hasContent
        onTranscriptVisibilityChange?(hasContent)
    }

    private func scrollTranscriptToBottom() {
        let length = (transcriptTextView.string as NSString).length
        guard length > 0 else { return }
        transcriptTextView.scrollRangeToVisible(NSRange(location: length, length: 0))
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
