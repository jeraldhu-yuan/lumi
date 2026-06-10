import Foundation

enum AgentEvent {
    case status(String)
    case sessionStarted(id: String)
    case delta(String)
    case approvalRequest(description: String, respond: (Bool) -> Void)
    case completed(sessionId: String?, finalMessage: String)
    case failed(String)
}

struct BackendCapabilities {
    let usesWorkspace: Bool
    let supportsApprovals: Bool
    let canOpenCompanionApp: Bool
}

enum BackendKind: String, CaseIterable {
    case codex
    case claudeCode = "claude-code"
    case anthropic
    case openAICompatible = "openai"

    var displayName: String {
        switch self {
        case .codex: return "Codex"
        case .claudeCode: return "Claude Code"
        case .anthropic: return "Claude"
        case .openAICompatible: return "Local Model"
        }
    }
}

protocol AgentBackend: AnyObject {
    var kind: BackendKind { get }
    var capabilities: BackendCapabilities { get }

    func submit(
        prompt: String,
        workspacePath: String,
        existingSessionId: String?,
        onEvent: @escaping (AgentEvent) -> Void
    )

    func cancel()
    func reset()
}

enum BackendFactory {
    static func make(_ kind: BackendKind) -> AgentBackend {
        switch kind {
        case .codex: return CodexBackend()
        case .claudeCode: return ClaudeCodeBackend()
        case .anthropic: return AnthropicBackend()
        case .openAICompatible: return OpenAICompatibleBackend()
        }
    }
}
