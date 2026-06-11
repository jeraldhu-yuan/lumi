import Foundation

struct AgentAttachment: Equatable {
    enum Kind: Equatable {
        case image
        case file
        case directory
    }

    let url: URL
    let kind: Kind
    let label: String?

    init(url: URL, kind: Kind, label: String? = nil) {
        self.url = url
        self.kind = kind
        self.label = label
    }

    var displayName: String {
        if let label, !label.isEmpty {
            return label
        }
        let name = url.lastPathComponent
        return name.isEmpty ? url.path : name
    }

    static func from(url: URL) -> AgentAttachment {
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue {
            return AgentAttachment(url: url, kind: .directory)
        }

        let imageExtensions = Set(["png", "jpg", "jpeg", "gif", "heic", "webp", "tif", "tiff"])
        let kind: Kind = imageExtensions.contains(url.pathExtension.lowercased()) ? .image : .file
        return AgentAttachment(url: url, kind: kind)
    }
}

struct AgentRequest: Equatable {
    let prompt: String
    let attachments: [AgentAttachment]

    var promptForPathAwareBackend: String {
        guard !attachments.isEmpty else { return prompt }

        let paths = attachments.map { attachment in
            "- \(attachment.displayName): \(attachment.url.path)"
        }.joined(separator: "\n")

        return """
        \(prompt)

        Attached local items:
        \(paths)
        """
    }
}

enum ConversationRole: Equatable {
    case user
    case assistant
    case system
}

struct ConversationMessage: Equatable {
    let role: ConversationRole
    var text: String
}
