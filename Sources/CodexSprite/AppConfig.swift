import Foundation

enum AppConfig {
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

    static let bundleIdentifier = "com.github.jj9276489.codexdesktopsprite"
}
