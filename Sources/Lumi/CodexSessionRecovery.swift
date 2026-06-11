import Foundation

struct CodexSessionRecovery {
    let requestedSessionID: String?
    private(set) var didRetryWithFreshThread = false

    mutating func shouldRetryWithFreshThread(responseID: Int?) -> Bool {
        guard responseID == 2,
              requestedSessionID?.isEmpty == false,
              !didRetryWithFreshThread else { return false }

        didRetryWithFreshThread = true
        return true
    }

    var readyThreadIsNew: Bool {
        requestedSessionID?.isEmpty != false || didRetryWithFreshThread
    }
}
