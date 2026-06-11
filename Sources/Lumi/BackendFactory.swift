import Foundation

enum BackendFactory {
    static func make(_ kind: BackendKind) -> AgentBackend {
        switch kind {
        case .codex: return CodexBackend()
        case .claudeCode: return ClaudeCodeBackend()
        }
    }
}
