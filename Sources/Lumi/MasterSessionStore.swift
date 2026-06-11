import Foundation

final class MasterSessionStore {
    private static let defaultsKey = "LumiMasterSessions"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func sessionID(for kind: BackendKind, workspacePath: String) -> String? {
        sessions[Self.key(for: kind, workspacePath: workspacePath)]
    }

    func setSessionID(_ sessionID: String, for kind: BackendKind, workspacePath: String) {
        var updated = sessions
        updated[Self.key(for: kind, workspacePath: workspacePath)] = sessionID
        defaults.set(updated, forKey: Self.defaultsKey)
    }

    func clearSession(for kind: BackendKind, workspacePath: String) {
        var updated = sessions
        updated.removeValue(forKey: Self.key(for: kind, workspacePath: workspacePath))
        defaults.set(updated, forKey: Self.defaultsKey)
    }

    private var sessions: [String: String] {
        defaults.dictionary(forKey: Self.defaultsKey) as? [String: String] ?? [:]
    }

    private static func key(for kind: BackendKind, workspacePath: String) -> String {
        "\(kind.rawValue)|\(URL(fileURLWithPath: workspacePath).standardizedFileURL.path)"
    }
}
