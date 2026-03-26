import Foundation

/// A pending NIP-46 request awaiting user approval.
struct PendingRequest: Identifiable, Sendable {
    let id: String                  // NIP-46 request ID
    let appName: String
    let appId: UUID
    let clientPubkey: String
    let method: String
    let kind: Int?
    let contentPreview: String?     // first 200 chars of event content
    let rawParams: [String]         // original request params
    let receivedAt: Date

    /// Human-readable description of the request.
    var displayTitle: String {
        if method == "sign_event", let kind {
            return "Sign: \(EventKindLabel.name(for: kind))"
        }
        switch method {
        case "nip44_encrypt": return "Encrypt Message"
        case "nip44_decrypt": return "Decrypt Message"
        case "nip04_encrypt": return "Encrypt DM (NIP-04)"
        case "nip04_decrypt": return "Decrypt DM (NIP-04)"
        case "connect": return "Connect"
        default: return method
        }
    }
}

/// Sequential, deduplicated request queue.
///
/// Presents one request at a time to the user. Prevents the same request
/// (same NIP-46 ID) from being processed twice (relay deduplication).
@MainActor @Observable
final class RequestQueue {
    /// The current request being presented to the user. Nil when queue is empty.
    private(set) var currentRequest: PendingRequest?

    /// Number of requests waiting behind the current one.
    var pendingCount: Int { queue.count }

    private var queue: [PendingRequest] = []
    private var processedIds: Set<String> = []
    private var responseHandler: ((String, Bool, PermissionEngine.RememberDuration?) -> Void)?

    /// Set the handler called when the user approves or denies a request.
    ///
    /// - Parameter handler: `(requestId, approved, rememberDuration)`
    func onResponse(_ handler: @escaping (String, Bool, PermissionEngine.RememberDuration?) -> Void) {
        self.responseHandler = handler
    }

    /// Enqueue a request. Deduplicates by NIP-46 request ID.
    func enqueue(_ request: PendingRequest) {
        guard !processedIds.contains(request.id) else { return }
        processedIds.insert(request.id)

        if currentRequest == nil {
            currentRequest = request
        } else {
            queue.append(request)
        }
    }

    /// Approve the current request.
    func approve(remember: PermissionEngine.RememberDuration? = nil) {
        guard let request = currentRequest else { return }
        responseHandler?(request.id, true, remember)
        processNext()
    }

    /// Deny the current request.
    func deny(remember: PermissionEngine.RememberDuration? = nil) {
        guard let request = currentRequest else { return }
        responseHandler?(request.id, false, remember)
        processNext()
    }

    /// Clear all pending requests (e.g., on disconnect).
    func clear() {
        currentRequest = nil
        queue.removeAll()
    }

    private func processNext() {
        if queue.isEmpty {
            currentRequest = nil
        } else {
            currentRequest = queue.removeFirst()
        }
    }
}
