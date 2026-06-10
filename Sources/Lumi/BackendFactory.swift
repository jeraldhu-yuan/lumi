import Foundation

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
