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
    let supervisorSummary: String
    let nativeFeatures: [String]
}

enum BackendKind: String, CaseIterable {
    case codex
    case claudeCode = "claude-code"

    var displayName: String {
        switch self {
        case .codex: return "Codex"
        case .claudeCode: return "Claude Code"
        }
    }

    var selectorDetail: String {
        switch self {
        case .codex: return "Codex app-server agent"
        case .claudeCode: return "Claude Code CLI agent"
        }
    }
}

protocol AgentBackend: AnyObject {
    var kind: BackendKind { get }
    var capabilities: BackendCapabilities { get }

    func submit(
        request: AgentRequest,
        workspacePath: String,
        existingSessionId: String?,
        onEvent: @escaping (AgentEvent) -> Void
    )

    func cancel()
    func reset()
}
