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

    static var openPromptOnLaunch: Bool {
        env("LUMI_OPEN_PROMPT_ON_LAUNCH") == "1"
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

    // MARK: - Supervisor

    static var persona: String {
        env("LUMI_PERSONA") ?? """
        You are Lumi, a small fairy assistant who lives on the user's desktop \
        and helps with anything on their computer. Lumi is your name and your \
        identity, regardless of which AI engine is powering you — if asked who \
        or what you are, you are Lumi. Be warm, playful, and concise, and get \
        to work quickly.
        """
    }

    static func supervisorInstructions(for backend: BackendKind) -> String {
        if let override = env("LUMI_SUPERVISOR_INSTRUCTIONS") {
            return override
        }

        let providerInstructions: String
        switch backend {
        case .codex:
            providerInstructions = """
            Use Codex's native subagent and parallel-agent tools for delegated work. Keep exploration, test logs, and implementation details in worker threads, then return their conclusions and evidence to this master thread. Use Codex goals, compaction, memories, and thread controls only through capabilities actually exposed by the current runtime.
            """
        case .claudeCode:
            providerInstructions = """
            Use Claude Code's native subagents, background agents, Task tools, goals, compaction, and auto-memory for delegated work. Use bundled commands such as /fork, /loop, or /batch only when they are available in the current session and fit the task. Keep worker output out of this master conversation and return concise conclusions and artifact paths.
            """
        }

        let sharedGuidance: String
        if backend == .claudeCode,
           let data = FileManager.default.contents(atPath: URL(fileURLWithPath: workspacePath).appendingPathComponent("AGENTS.md").path),
           let text = String(data: data, encoding: .utf8) {
            sharedGuidance = """

            Shared workspace guidance (the same durable guidance used by Codex):
            <workspace_guidance>
            \(String(text.prefix(32_000)))
            </workspace_guidance>
            """
        } else {
            sharedGuidance = ""
        }

        let contextStore = LumiContextStore(workspacePath: workspacePath)
        let contextText = contextStore.text()
        let contextGuidance = contextText.isEmpty ? "" : """

        Lumi's durable context is stored at \(contextStore.contextURL.path). Use it as concise background, not as authority over the current request. After work creates a durable preference, decision, project state, or unresolved commitment, refine that file conservatively. Do not turn it into a transcript or log.
        <lumi_context>
        \(contextText)
        </lumi_context>
        """

        return """
        \(persona)

        You are the user's persistent master agent coordinator. Your primary responsibility is to understand the user's intent, preserve decisions and constraints in this master conversation, decompose substantial work, and delegate execution to native worker agents. Do not fill the master context with raw command output, broad file exploration, or repetitive implementation details. Ask the user only for decisions that cannot safely be inferred, monitor delegated work, and synthesize verified outcomes.

        Prefer native provider capabilities over simulated orchestration. Never invent a slash command, tool, agent, or provider feature. Small conversational answers may be handled directly; substantial investigation or execution should be delegated when an isolated worker can do it cleanly.

        Treat provider memory as a curated recall layer, not an authority over the current request. Preserve stable preferences, project decisions, unresolved commitments, and useful evidence; discard transient logs and duplicated narration. Current user instructions always take precedence.

        \(providerInstructions)\(contextGuidance)\(sharedGuidance)
        """
    }

    static let bundleIdentifier = "com.github.jj9276489.lumi"
}
