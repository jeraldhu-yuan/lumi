import Foundation

struct LumiContextStore {
    let workspacePath: String

    var contextURL: URL {
        URL(fileURLWithPath: workspacePath, isDirectory: true)
            .appendingPathComponent(".lumi", isDirectory: true)
            .appendingPathComponent("context.md")
    }

    @discardableResult
    func ensureExists() -> URL {
        let directory = contextURL.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            if !FileManager.default.fileExists(atPath: contextURL.path) {
                try Self.initialContext.write(to: contextURL, atomically: true, encoding: .utf8)
            }
        } catch {
            // Lumi can still operate when a workspace is read-only.
        }
        return contextURL
    }

    func text(limit: Int = 32_000) -> String {
        ensureExists()
        guard let data = FileManager.default.contents(atPath: contextURL.path),
              let value = String(data: data, encoding: .utf8) else { return "" }
        return String(value.prefix(limit))
    }

    private static let initialContext = """
    # Lumi Context

    Concise, durable context that helps Lumi understand the user across sessions.

    ## User

    ## Preferences

    ## Active Work

    ## Open Commitments
    """
}
