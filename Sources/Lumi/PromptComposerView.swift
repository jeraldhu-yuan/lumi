import AppKit

final class PromptComposerView: NSView, NSTextViewDelegate {
    var onSubmit: ((AgentRequest) -> Void)?
    var onCancel: (() -> Void)?
    var onTextChange: ((String) -> Void)?

    private let inputTextView = ComposerTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 62))
    private let inputContainer = NSView()
    private let inputScroll = NSScrollView()
    private let placeholderLabel = NSTextField(labelWithString: "What do you need?")
    private let attachmentStack = NSStackView()
    private let attachButton = NSButton()
    private let sendButton = NSButton()
    private var inputHeightConstraint: NSLayoutConstraint!
    private var attachments: [AgentAttachment] = []
    private var isSending = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        inputScroll.hasVerticalScroller = true
        inputScroll.autohidesScrollers = true
        inputScroll.borderType = .noBorder
        inputScroll.drawsBackground = false
        inputScroll.documentView = inputTextView

        inputContainer.wantsLayer = true
        inputContainer.layer?.backgroundColor = NSColor.textBackgroundColor.withAlphaComponent(0.62).cgColor
        inputContainer.layer?.cornerRadius = 14
        inputContainer.layer?.masksToBounds = true

        inputTextView.font = .systemFont(ofSize: 14)
        inputTextView.isRichText = false
        inputTextView.allowsUndo = true
        inputTextView.drawsBackground = false
        inputTextView.textContainerInset = NSSize(width: 13, height: 11)
        inputTextView.textContainer?.lineFragmentPadding = 0
        inputTextView.textContainer?.widthTracksTextView = true
        inputTextView.isHorizontallyResizable = false
        inputTextView.isVerticallyResizable = true
        inputTextView.autoresizingMask = [.width]
        inputTextView.minSize = NSSize(width: 0, height: 62)
        inputTextView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        inputTextView.delegate = self
        inputTextView.onSubmit = { [weak self] in self?.submit() }
        inputTextView.onPasteAttachments = { [weak self] pasteboard in
            self?.addAttachments(from: pasteboard) ?? false
        }

        placeholderLabel.font = .systemFont(ofSize: 14)
        placeholderLabel.textColor = .placeholderTextColor
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false

        attachmentStack.orientation = .horizontal
        attachmentStack.alignment = .centerY
        attachmentStack.spacing = 6
        attachmentStack.isHidden = true

        Self.styleIconButton(attachButton, symbol: "paperclip", pointSize: 16, tooltip: "Attach files or folders")
        attachButton.target = self
        attachButton.action = #selector(chooseAttachments)

        Self.styleIconButton(sendButton, symbol: "arrow.up.circle.fill", pointSize: 26, tooltip: "Send (Command-Return)")
        sendButton.contentTintColor = .controlAccentColor
        sendButton.target = self
        sendButton.action = #selector(sendPressed)

        [inputScroll, attachButton, sendButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            inputContainer.addSubview($0)
        }

        let stack = NSStackView(views: [attachmentStack, inputContainer])
        stack.orientation = .vertical
        stack.spacing = 7
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        addSubview(placeholderLabel)

        inputHeightConstraint = inputContainer.heightAnchor.constraint(equalToConstant: 62)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            inputHeightConstraint,
            inputScroll.leadingAnchor.constraint(equalTo: inputContainer.leadingAnchor),
            inputScroll.trailingAnchor.constraint(equalTo: attachButton.leadingAnchor, constant: -8),
            inputScroll.topAnchor.constraint(equalTo: inputContainer.topAnchor),
            inputScroll.bottomAnchor.constraint(equalTo: inputContainer.bottomAnchor),
            attachButton.widthAnchor.constraint(equalToConstant: 34),
            attachButton.heightAnchor.constraint(equalToConstant: 34),
            attachButton.trailingAnchor.constraint(equalTo: sendButton.leadingAnchor, constant: -2),
            attachButton.bottomAnchor.constraint(equalTo: inputContainer.bottomAnchor, constant: -8),
            sendButton.widthAnchor.constraint(equalToConstant: 34),
            sendButton.heightAnchor.constraint(equalToConstant: 34),
            sendButton.trailingAnchor.constraint(equalTo: inputContainer.trailingAnchor, constant: -8),
            sendButton.bottomAnchor.constraint(equalTo: inputContainer.bottomAnchor, constant: -8),
            placeholderLabel.leadingAnchor.constraint(equalTo: inputContainer.leadingAnchor, constant: 13),
            placeholderLabel.topAnchor.constraint(equalTo: inputScroll.topAnchor, constant: 11),
            placeholderLabel.trailingAnchor.constraint(lessThanOrEqualTo: attachButton.leadingAnchor, constant: -8)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(backendName: String) {
        placeholderLabel.stringValue = "What do you need?"
    }

    func focus() {
        window?.makeFirstResponder(inputTextView)
    }

    func setSending(_ sending: Bool) {
        isSending = sending
        inputTextView.isEditable = !sending
        attachButton.isEnabled = !sending

        let symbol = sending ? "stop.circle.fill" : "arrow.up.circle.fill"
        let config = NSImage.SymbolConfiguration(pointSize: 26, weight: .medium)
        sendButton.image = NSImage(systemSymbolName: symbol, accessibilityDescription: sending ? "Stop" : "Send")?
            .withSymbolConfiguration(config)
        sendButton.toolTip = sending ? "Stop" : "Send (Command-Return)"
        updatePlaceholderVisibility()
    }

    func clear() {
        inputTextView.string = ""
        attachments = []
        rebuildAttachmentChips()
        updatePlaceholderVisibility()
        updateInputHeight()
        onTextChange?("")
    }

    func addAttachments(_ newAttachments: [AgentAttachment]) {
        guard !newAttachments.isEmpty else { return }
        let knownPaths = Set(attachments.map { $0.url.standardizedFileURL.path })
        attachments.append(contentsOf: newAttachments.filter { !knownPaths.contains($0.url.standardizedFileURL.path) })
        rebuildAttachmentChips()
    }

    func textDidChange(_ notification: Notification) {
        updatePlaceholderVisibility()
        updateInputHeight()
        onTextChange?(inputTextView.string)
    }

    private func updatePlaceholderVisibility() {
        placeholderLabel.isHidden = !inputTextView.string.isEmpty || isSending
    }

    private func updateInputHeight() {
        inputTextView.layoutManager?.ensureLayout(for: inputTextView.textContainer!)
        let usedHeight = inputTextView.layoutManager?.usedRect(for: inputTextView.textContainer!).height ?? 0
        inputHeightConstraint.constant = min(132, max(62, ceil(usedHeight) + 24))
        invalidateIntrinsicContentSize()
    }

    @objc private func sendPressed() {
        isSending ? onCancel?() : submit()
    }

    private func submit() {
        guard !isSending else { return }
        onSubmit?(AgentRequest(prompt: inputTextView.string, attachments: attachments))
    }

    @objc private func chooseAttachments() {
        guard let window else { return }
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK else { return }
            self?.addAttachments(panel.urls.map(AgentAttachment.from(url:)))
        }
    }

    private func addAttachments(from pasteboard: NSPasteboard) -> Bool {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [URL], !urls.isEmpty {
            addAttachments(urls.map(AgentAttachment.from(url:)))
            return true
        }

        let imageTypes: [(NSPasteboard.PasteboardType, String)] = [(.png, "png"), (.tiff, "tiff")]
        for (type, fileExtension) in imageTypes {
            guard let data = pasteboard.data(forType: type), let url = Self.writeTemporaryAttachment(data: data, fileExtension: fileExtension) else {
                continue
            }
            addAttachments([AgentAttachment(url: url, kind: .image, label: "Pasted image")])
            return true
        }

        return false
    }

    private static func writeTemporaryAttachment(data: Data, fileExtension: String) -> URL? {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("LumiAttachments", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let url = directory.appendingPathComponent("clipboard-\(UUID().uuidString).\(fileExtension)")
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    private func rebuildAttachmentChips() {
        attachmentStack.arrangedSubviews.forEach {
            attachmentStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        for (index, attachment) in attachments.enumerated() {
            let button = NSButton(title: "\(attachment.displayName)  x", target: self, action: #selector(removeAttachment(_:)))
            button.tag = index
            button.bezelStyle = .recessed
            button.controlSize = .small
            button.font = .systemFont(ofSize: 11, weight: .medium)
            button.toolTip = attachment.url.path
            attachmentStack.addArrangedSubview(button)
        }

        attachmentStack.isHidden = attachments.isEmpty
        invalidateIntrinsicContentSize()
    }

    @objc private func removeAttachment(_ sender: NSButton) {
        guard attachments.indices.contains(sender.tag) else { return }
        attachments.remove(at: sender.tag)
        rebuildAttachmentChips()
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

private final class ComposerTextView: NSTextView {
    var onSubmit: (() -> Void)?
    var onPasteAttachments: ((NSPasteboard) -> Bool)?

    override convenience init(frame frameRect: NSRect) {
        let storage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        let container = NSTextContainer(
            containerSize: NSSize(width: frameRect.width, height: CGFloat.greatestFiniteMagnitude)
        )
        container.widthTracksTextView = true
        storage.addLayoutManager(layoutManager)
        layoutManager.addTextContainer(container)
        self.init(frame: frameRect, textContainer: container)
    }

    override init(frame frameRect: NSRect, textContainer container: NSTextContainer?) {
        super.init(frame: frameRect, textContainer: container)
        registerForDraggedTypes([.fileURL, .png, .tiff])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func keyDown(with event: NSEvent) {
        if handleEditingShortcut(event) {
            return
        }

        let modifiers = event.modifierFlags.intersection([.command, .control, .option, .shift])
        if modifiers == .command, event.keyCode == 36 {
            onSubmit?()
            return
        }
        super.keyDown(with: event)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        handleEditingShortcut(event) || super.performKeyEquivalent(with: event)
    }

    override func paste(_ sender: Any?) {
        if onPasteAttachments?(NSPasteboard.general) == true {
            return
        }

        if let text = NSPasteboard.general.string(forType: .string) {
            insertText(text, replacementRange: selectedRange())
            return
        }
        super.paste(sender)
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        canAccept(sender.draggingPasteboard) ? .copy : []
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        onPasteAttachments?(sender.draggingPasteboard) ?? false
    }

    private func canAccept(_ pasteboard: NSPasteboard) -> Bool {
        pasteboard.canReadObject(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true])
            || pasteboard.availableType(from: [.png, .tiff]) != nil
    }

    private func handleEditingShortcut(_ event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection([.command, .control, .option, .shift])
        let key = event.charactersIgnoringModifiers?.lowercased()

        if modifiers == .command, key == "v" || event.keyCode == 9 {
            paste(nil)
            return true
        }

        if modifiers == .command, key == "a" || event.keyCode == 0 {
            selectAll(nil)
            return true
        }

        return false
    }
}
