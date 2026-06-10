import Foundation

enum AppConfig {
    private static let backendDefaultsKey = "LumiBackend"

    private static func env(_ key: String) -> String? {
        guard let value = ProcessInfo.processInfo.environment[key],
              !value.isEmpty else { return nil }
        return value
    }

    static var defaultWorkspacePath: String {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("CODEX - DIGITAL ASSISTANT TASKS")
            .path
    }

    static var workspacePath: String {
        env("LUMI_WORKSPACE") ?? defaultWorkspacePath
    }

    static var backendKind: BackendKind {
        if let value = env("LUMI_BACKEND"), let kind = BackendKind(rawValue: value) {
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

    static let bundledCodexPath = "/Applications/Codex.app/Contents/Resources/codex"
    static let fallbackCodexPath = "/opt/homebrew/bin/codex"

    static var codexExecutablePath: String {
        if let override = env("LUMI_CODEX_PATH"),
           FileManager.default.isExecutableFile(atPath: override) {
            return override
        }

        if FileManager.default.isExecutableFile(atPath: bundledCodexPath) {
            return bundledCodexPath
        }

        return fallbackCodexPath
    }

    static var approvalPolicy: String {
        env("LUMI_CODEX_APPROVAL_POLICY") ?? "on-request"
    }

    static var sandboxMode: String {
        env("LUMI_CODEX_SANDBOX") ?? "workspace-write"
    }

    static var codexAutoApprove: Bool {
        env("LUMI_CODEX_AUTO_APPROVE") == "1"
    }

    // MARK: - Claude Code

    static var claudeExecutablePath: String? {
        if let override = env("LUMI_CLAUDE_PATH"),
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
        env("LUMI_CLAUDE_PERMISSION_MODE") ?? "acceptEdits"
    }

    // MARK: - Anthropic API

    static var anthropicAPIKey: String? {
        env("ANTHROPIC_API_KEY") ?? UserDefaults.standard.string(forKey: "LumiAnthropicAPIKey")
    }

    static var anthropicModel: String {
        env("LUMI_ANTHROPIC_MODEL") ?? "claude-opus-4-8"
    }

    // MARK: - OpenAI-compatible endpoint

    static var openAIBaseURL: String {
        env("LUMI_OPENAI_BASE_URL")
            ?? UserDefaults.standard.string(forKey: "LumiOpenAIBaseURL")
            ?? "http://localhost:11434/v1"
    }

    static var openAIModel: String {
        env("LUMI_OPENAI_MODEL")
            ?? UserDefaults.standard.string(forKey: "LumiOpenAIModel")
            ?? "llama3.2"
    }

    static var openAIAPIKey: String? {
        env("LUMI_OPENAI_API_KEY")
    }

    // MARK: - Shared chat settings

    static var chatSystemPrompt: String? {
        env("LUMI_SYSTEM_PROMPT")
            ?? "You are Lumi, a friendly assistant living in a small desktop sprite. Keep responses concise and conversational."
    }

    static let bundleIdentifier = "com.github.jj9276489.lumi"
}
