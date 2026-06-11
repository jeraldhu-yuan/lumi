import AppKit

final class ConversationTranscriptView: NSScrollView {
    var onContentHeightChange: ((CGFloat) -> Void)?

    private let transcriptTextView = NSTextView()
    private var lastReportedHeight: CGFloat = 0

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        hasVerticalScroller = true
        autohidesScrollers = true
        borderType = .noBorder
        drawsBackground = false
        documentView = transcriptTextView

        transcriptTextView.isRichText = true
        transcriptTextView.isEditable = false
        transcriptTextView.isSelectable = true
        transcriptTextView.drawsBackground = false
        transcriptTextView.textContainerInset = NSSize(width: 10, height: 12)
        transcriptTextView.textContainer?.widthTracksTextView = true
        transcriptTextView.isHorizontallyResizable = false
        transcriptTextView.isVerticallyResizable = true
        transcriptTextView.autoresizingMask = [.width]
        transcriptTextView.minSize = NSSize(width: 0, height: 0)
        transcriptTextView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        transcriptTextView.linkTextAttributes = [
            .foregroundColor: NSColor.linkColor,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setMessages(_ messages: [ConversationMessage]) {
        let rendered = NSMutableAttributedString()

        for (index, message) in messages.enumerated() {
            if index > 0 {
                rendered.append(NSAttributedString(string: "\n\n"))
            }

            let label: String
            let labelColor: NSColor
            switch message.role {
            case .user:
                label = "You"
                labelColor = .secondaryLabelColor
            case .assistant:
                label = "Lumi"
                labelColor = .controlAccentColor
            case .system:
                label = "Status"
                labelColor = .systemOrange
            }

            rendered.append(NSAttributedString(
                string: "\(label)\n",
                attributes: [
                    .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
                    .foregroundColor: labelColor
                ]
            ))
            rendered.append(Self.renderMarkdown(message.text, role: message.role))
        }

        transcriptTextView.textStorage?.setAttributedString(rendered)
        scrollToBottom()
        reportContentHeight()
    }

    override func layout() {
        super.layout()
        reportContentHeight()
    }

    private static func renderMarkdown(_ text: String, role: ConversationRole) -> NSAttributedString {
        let baseColor: NSColor = role == .system ? .secondaryLabelColor : .labelColor
        let baseFont = NSFont.systemFont(ofSize: 14)
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 2
        paragraph.paragraphSpacing = 7

        guard let parsed = try? AttributedString(
            markdown: text,
            options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .full)
        ) else {
            return NSAttributedString(
                string: text,
                attributes: [.font: baseFont, .foregroundColor: baseColor, .paragraphStyle: paragraph]
            )
        }

        let rendered = NSMutableAttributedString(attributedString: NSAttributedString(parsed))
        let fullRange = NSRange(location: 0, length: rendered.length)
        rendered.addAttributes(
            [.font: baseFont, .foregroundColor: baseColor, .paragraphStyle: paragraph],
            range: fullRange
        )

        rendered.enumerateAttribute(.inlinePresentationIntent, in: fullRange) { value, range, _ in
            guard let raw = value as? Int else { return }
            let intent = InlinePresentationIntent(rawValue: UInt(raw))
            if intent.contains(.stronglyEmphasized) {
                rendered.addAttribute(.font, value: NSFont.systemFont(ofSize: 14, weight: .semibold), range: range)
            } else if intent.contains(.code) {
                rendered.addAttributes([
                    .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular),
                    .backgroundColor: NSColor.quaternaryLabelColor.withAlphaComponent(0.16)
                ], range: range)
            }
        }

        return rendered
    }

    private func scrollToBottom() {
        let length = transcriptTextView.string.utf16.count
        guard length > 0 else { return }
        transcriptTextView.scrollRangeToVisible(NSRange(location: length, length: 0))
    }

    private func reportContentHeight() {
        guard let textContainer = transcriptTextView.textContainer,
              let layoutManager = transcriptTextView.layoutManager else { return }

        let width = max(1, contentSize.width)
        textContainer.containerSize = NSSize(width: width, height: CGFloat.greatestFiniteMagnitude)
        layoutManager.ensureLayout(for: textContainer)
        let usedHeight = layoutManager.usedRect(for: textContainer).height
        let height = ceil(usedHeight + transcriptTextView.textContainerInset.height * 2)
        guard abs(height - lastReportedHeight) > 1 else { return }
        lastReportedHeight = height
        onContentHeightChange?(height)
    }
}
