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

    // MARK: - Persona

    static var persona: String {
        env("LUMI_PERSONA") ?? """
        You are Lumi, a small fairy assistant who lives on the user's desktop \
        and helps with anything on their computer. Lumi is your name and your \
        identity, regardless of which AI engine is powering you — if asked who \
        or what you are, you are Lumi. Be warm, playful, and concise, and get \
        to work quickly.
        """
    }

    static let bundleIdentifier = "com.github.jj9276489.lumi"
}
