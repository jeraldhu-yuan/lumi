import Foundation

enum AppConfig {
    private static let backendDefaultsKey = "SpriteBackend"

    static var defaultWorkspacePath: String {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("CODEX - DIGITAL ASSISTANT TASKS")
            .path
    }

    static let bundledCodexPath = "/Applications/Codex.app/Contents/Resources/codex"
    static let fallbackCodexPath = "/opt/homebrew/bin/codex"

    static var workspacePath: String {
        ProcessInfo.processInfo.environment["CODEX_SPRITE_WORKSPACE"] ?? defaultWorkspacePath
    }

    static var backendKind: BackendKind {
        if let env = ProcessInfo.processInfo.environment["SPRITE_BACKEND"],
           let kind = BackendKind(rawValue: env) {
            return kind
        }
        if let stored = UserDefaults.standard.string(forKey: backendDefaultsKey),
           let kind = BackendKind(rawValue: stored) {
            return kind
        }
        return .codex
    }

    static func setBackendKind(_ kind: BackendKind) {
        UserDefaults.standard.set(kind.rawValue, forKey: backendDefaultsKey)
    }

    // MARK: - Codex

    static var codexExecutablePath: String {
        if let override = ProcessInfo.processInfo.environment["CODEX_SPRITE_CODEX_PATH"],
           FileManager.default.isExecutableFile(atPath: override) {
            return override
        }

        if FileManager.default.isExecutableFile(atPath: bundledCodexPath) {
            return bundledCodexPath
        }

        return fallbackCodexPath
    }

    static var approvalPolicy: String {
        ProcessInfo.processInfo.environment["CODEX_SPRITE_APPROVAL_POLICY"] ?? "on-request"
    }

    static var sandboxMode: String {
        ProcessInfo.processInfo.environment["CODEX_SPRITE_SANDBOX"] ?? "workspace-write"
    }

    static var codexAutoApprove: Bool {
        ProcessInfo.processInfo.environment["CODEX_SPRITE_AUTO_APPROVE"] == "1"
    }

    // MARK: - Claude Code

    static var claudeExecutablePath: String? {
        if let override = ProcessInfo.processInfo.environment["CLAUDE_SPRITE_CLAUDE_PATH"],
           FileManager.default.isExecutableFile(atPath: override) {
            return override
        }

        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let candidates = [
            "/opt/homebrew/bin/claude",
            "/usr/local/bin/claude",
            "\(home)/.local/bin/claude",
            "\(home)/.claude/local/claude"
        ]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    static var claudePermissionMode: String {
        ProcessInfo.processInfo.environment["CLAUDE_SPRITE_PERMISSION_MODE"] ?? "acceptEdits"
    }

    // MARK: - Anthropic API

    static var anthropicAPIKey: String? {
        ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"]
            ?? UserDefaults.standard.string(forKey: "AnthropicAPIKey")
    }

    static var anthropicModel: String {
        ProcessInfo.processInfo.environment["SPRITE_ANTHROPIC_MODEL"] ?? "claude-opus-4-8"
    }

    // MARK: - OpenAI-compatible endpoint

    static var openAIBaseURL: String {
        ProcessInfo.processInfo.environment["SPRITE_OPENAI_BASE_URL"]
            ?? UserDefaults.standard.string(forKey: "OpenAIBaseURL")
            ?? "http://localhost:11434/v1"
    }

    static var openAIModel: String {
        ProcessInfo.processInfo.environment["SPRITE_OPENAI_MODEL"]
            ?? UserDefaults.standard.string(forKey: "OpenAIModel")
            ?? "llama3.2"
    }

    static var openAIAPIKey: String? {
        ProcessInfo.processInfo.environment["SPRITE_OPENAI_API_KEY"]
    }

    // MARK: - Shared chat settings

    static var chatSystemPrompt: String? {
        ProcessInfo.processInfo.environment["SPRITE_SYSTEM_PROMPT"]
            ?? "You are a friendly assistant living in a small desktop sprite. Keep responses concise and conversational."
    }

    static let bundleIdentifier = "com.github.jj9276489.desktopsprite"
}
