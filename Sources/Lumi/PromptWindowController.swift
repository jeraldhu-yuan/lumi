import AppKit

@MainActor
final class PromptWindowController: NSObject {
    private static let compactHeight: CGFloat = 184

    let window: NSPanel

    private let promptView: PromptView
    private let onSubmit: (AgentRequest) -> Void
    private let onTextChange: (String) -> Void
    private let onClose: () -> Void
    private var transcriptContentHeight: CGFloat = 160
    private var isTranscriptVisible = false

    init(
        onSubmit: @escaping (AgentRequest) -> Void,
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
            contentRect: NSRect(x: 0, y: 0, width: 520, height: Self.compactHeight),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .utilityWindow, .fullSizeContentView],
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
        window.minSize = NSSize(width: 460, height: Self.compactHeight)
        window.contentView = promptView

        super.init()

        window.delegate = self
        window.standardWindowButton(.miniaturizeButton)?.target = self
        window.standardWindowButton(.miniaturizeButton)?.action = #selector(minimizePrompt)
        promptView.onTextChange = { [weak self] text in self?.onTextChange(text) }
        promptView.onSubmit = { [weak self] request in self?.onSubmit(request) }
        promptView.onTranscriptVisibilityChange = { [weak self] expanded in self?.setExpanded(expanded) }
        promptView.onTranscriptHeightChange = { [weak self] height in self?.setTranscriptHeight(height) }
    }

    func configure(for backend: AgentBackend) {
        window.title = "Lumi"
        promptView.configure(
            backendName: backend.kind.displayName,
            kind: backend.kind,
            capabilities: backend.capabilities,
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

    func setMessages(_ messages: [ConversationMessage]) {
        promptView.setMessages(messages)
    }

    func clearMessages() {
        promptView.setMessages([])
    }

    func clearPrompt() {
        promptView.clearPrompt()
    }

    func addAttachments(_ attachments: [AgentAttachment]) {
        promptView.addAttachments(attachments)
    }

    @objc private func minimizePrompt() {
        window.orderOut(nil)
        onClose()
    }

    private func setExpanded(_ expanded: Bool) {
        isTranscriptVisible = expanded
        resizeForCurrentContent()
    }

    private func setTranscriptHeight(_ height: CGFloat) {
        transcriptContentHeight = min(360, max(160, height))
        guard isTranscriptVisible else { return }
        resizeForCurrentContent()
    }

    private func resizeForCurrentContent() {
        let target = isTranscriptVisible ? Self.compactHeight + transcriptContentHeight + 11 : Self.compactHeight
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

private final class PromptView: NSVisualEffectView {
    var onSubmit: ((AgentRequest) -> Void)?
    var onTextChange: ((String) -> Void)?
    var onTranscriptVisibilityChange: ((Bool) -> Void)?
    var onTranscriptHeightChange: ((CGFloat) -> Void)?

    private let transcriptView = ConversationTranscriptView()
    private let composerView = PromptComposerView()
    private let titleLabel = NSTextField(labelWithString: "Lumi")
    private let statusLabel = NSTextField(labelWithString: "")
    private let newSessionButton = NSButton()
    private let openAppButton = NSButton()
    private let quitButton = NSButton()
    private let backendPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let onBackendChange: (BackendKind) -> Void
    private let openSleeve: ClosureSleeve
    private let quitSleeve: ClosureSleeve
    private let newThreadSleeve: ClosureSleeve
    private var transcriptHeightConstraint: NSLayoutConstraint!
    private var hasMessages = false

    init(
        onCancel: @escaping () -> Void,
        onOpenCompanionApp: @escaping () -> Void,
        onQuit: @escaping () -> Void,
        onNewThread: @escaping () -> Void,
        onBackendChange: @escaping (BackendKind) -> Void
    ) {
        self.onBackendChange = onBackendChange
        openSleeve = ClosureSleeve(onOpenCompanionApp)
        quitSleeve = ClosureSleeve(onQuit)
        newThreadSleeve = ClosureSleeve(onNewThread)
        super.init(frame: .zero)
        material = .hudWindow
        blendingMode = .behindWindow
        state = .active

        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        titleLabel.textColor = .labelColor

        backendPopup.menu = Self.makeBackendMenu()
        backendPopup.autoenablesItems = false
        backendPopup.controlSize = .small
        backendPopup.font = .systemFont(ofSize: 11, weight: .medium)
        backendPopup.target = self
        backendPopup.action = #selector(backendChanged)

        let titleRow = NSStackView(views: [titleLabel, NSView(), backendPopup])
        titleRow.orientation = .horizontal
        titleRow.spacing = 10
        titleRow.alignment = .centerY
        titleRow.setContentCompressionResistancePriority(.required, for: .vertical)

        transcriptView.isHidden = true
        transcriptView.setContentHuggingPriority(.defaultLow, for: .vertical)
        transcriptView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        transcriptHeightConstraint = transcriptView.heightAnchor.constraint(equalToConstant: 160)
        transcriptView.onContentHeightChange = { [weak self] height in
            guard let self else { return }
            let clampedHeight = min(360, max(160, height))
            self.transcriptHeightConstraint.constant = clampedHeight
            self.onTranscriptHeightChange?(clampedHeight)
        }
        composerView.onCancel = onCancel
        composerView.onSubmit = { [weak self] request in self?.onSubmit?(request) }
        composerView.onTextChange = { [weak self] text in self?.onTextChange?(text) }
        composerView.setContentCompressionResistancePriority(.required, for: .vertical)

        statusLabel.font = .systemFont(ofSize: 11)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.lineBreakMode = .byTruncatingTail
        statusLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        Self.styleIconButton(newSessionButton, symbol: "plus.bubble", pointSize: 14, tooltip: "Start fresh")
        newSessionButton.target = newThreadSleeve
        newSessionButton.action = #selector(ClosureSleeve.invoke)

        Self.styleIconButton(openAppButton, symbol: "arrow.up.forward.app", pointSize: 14, tooltip: "Open Codex Desktop")
        openAppButton.target = openSleeve
        openAppButton.action = #selector(ClosureSleeve.invoke)

        Self.styleIconButton(quitButton, symbol: "power", pointSize: 14, tooltip: "Quit Lumi")
        quitButton.target = quitSleeve
        quitButton.action = #selector(ClosureSleeve.invoke)

        let footerRow = NSStackView(views: [statusLabel, NSView(), newSessionButton, openAppButton, quitButton])
        footerRow.orientation = .horizontal
        footerRow.spacing = 11
        footerRow.alignment = .centerY
        footerRow.setContentCompressionResistancePriority(.required, for: .vertical)

        let stack = NSStackView(views: [titleRow, transcriptView, composerView, footerRow])
        stack.orientation = .vertical
        stack.spacing = 11
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 31),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -15)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(
        backendName: String,
        kind: BackendKind,
        capabilities: BackendCapabilities,
        showsCompanionApp: Bool,
        showsWorkspace: Bool
    ) {
        composerView.configure(backendName: backendName)
        backendPopup.toolTip = "Using \(backendName) in \(URL(fileURLWithPath: AppConfig.workspacePath).lastPathComponent)"
        openAppButton.isHidden = !showsCompanionApp
        if let item = backendPopup.menu?.items.first(where: { ($0.representedObject as? String) == kind.rawValue }) {
            backendPopup.select(item)
        }
    }

    func focus() {
        composerView.focus()
    }

    func update(status: String, isSending: Bool, threadId: String?) {
        let visibleStatus = status.trimmingCharacters(in: .whitespacesAndNewlines)
        statusLabel.stringValue = visibleStatus
        statusLabel.isHidden = visibleStatus.isEmpty
        statusLabel.toolTip = threadId.map { "Session: \($0)" }
        composerView.setSending(isSending)
        newSessionButton.isEnabled = !isSending
        backendPopup.isEnabled = !isSending
    }

    func setMessages(_ messages: [ConversationMessage]) {
        transcriptView.setMessages(messages)
        let shouldShow = !messages.isEmpty
        transcriptHeightConstraint.isActive = shouldShow
        transcriptView.isHidden = !shouldShow
        if shouldShow != hasMessages {
            hasMessages = shouldShow
            onTranscriptVisibilityChange?(shouldShow)
        }
    }

    func clearPrompt() {
        composerView.clear()
    }

    func addAttachments(_ attachments: [AgentAttachment]) {
        composerView.addAttachments(attachments)
    }

    @objc private func backendChanged() {
        guard let raw = backendPopup.selectedItem?.representedObject as? String,
              let kind = BackendKind(rawValue: raw) else { return }
        onBackendChange(kind)
    }

    private static func makeBackendMenu() -> NSMenu {
        let menu = NSMenu()
        for kind in BackendKind.allCases {
            let item = NSMenuItem(title: kind.displayName, action: nil, keyEquivalent: "")
            item.representedObject = kind.rawValue
            item.toolTip = kind.selectorDetail
            menu.addItem(item)
        }
        return menu
    }

    private static func styleIconButton(_ button: NSButton, symbol: String, pointSize: CGFloat, tooltip: String) {
        let config = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .medium)
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: tooltip)?.withSymbolConfiguration(config)
        button.isBordered = false
        button.contentTintColor = .secondaryLabelColor
        button.toolTip = tooltip
        button.imagePosition = .imageOnly
        button.setButtonType(.momentaryChange)
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
