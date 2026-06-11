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

    var isAgent: Bool {
        switch self {
        case .codex, .claudeCode: return true
        case .anthropic, .openAICompatible: return false
        }
    }

    var selectorDetail: String {
        switch self {
        case .codex: return "Codex app-server agent"
        case .claudeCode: return "Claude Code CLI agent"
        case .anthropic: return "Claude API chat"
        case .openAICompatible: return "Ollama or any OpenAI-compatible server"
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
