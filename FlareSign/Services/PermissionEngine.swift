import Foundation

/// Evaluates whether a NIP-46 request should be auto-approved, denied, or presented to the user.
enum PermissionEngine {

    enum Decision {
        case allow
        case deny
        case ask
    }

    /// Evaluate a request against an app's permission set.
    static func evaluate(
        method: String,
        kind: Int?,
        permissions: [Permission]
    ) -> Decision {
        // Find matching permission (most specific first: method + kind, then method-only)
        let activePermissions = permissions.filter { !$0.isExpired }

        // Try exact match (method + kind)
        if let kind {
            if let exact = activePermissions.first(where: { $0.method == method && $0.kind == kind }) {
                return policyToDecision(exact.policy)
            }
        }

        // Try method-level match (any kind)
        if let methodLevel = activePermissions.first(where: { $0.method == method && $0.kind == nil }) {
            return policyToDecision(methodLevel.policy)
        }

        // Fall back to default policy
        return defaultPolicy(method: method, kind: kind)
    }

    /// Default policies for NIP-46 methods.
    ///
    /// Conservative by default — most signing requires manual approval.
    /// Safe metadata operations are auto-approved.
    static func defaultPolicy(method: String, kind: Int?) -> Decision {
        switch method {
        case "get_public_key", "ping":
            return .allow

        case "connect":
            return .ask

        case "sign_event":
            guard let kind else { return .ask }
            switch kind {
            // Safe metadata — auto-approve
            case 0:     return .allow  // Profile metadata
            case 3:     return .allow  // Contact list
            case 10002: return .allow  // Relay list
            case 22242: return .allow  // Relay auth challenge
            // Everything else — ask
            default:    return .ask
            }

        case "nip04_encrypt", "nip04_decrypt",
             "nip44_encrypt", "nip44_decrypt":
            return .ask

        default:
            return .ask
        }
    }

    /// Time intervals for "Remember" options.
    enum RememberDuration {
        case thisTimeOnly
        case fifteenMinutes
        case oneHour
        case fourHours
        case always

        var expiresAt: Date? {
            switch self {
            case .thisTimeOnly: nil  // not saved
            case .fifteenMinutes: Date.now.addingTimeInterval(15 * 60)
            case .oneHour: Date.now.addingTimeInterval(3600)
            case .fourHours: Date.now.addingTimeInterval(4 * 3600)
            case .always: nil  // permanent
            }
        }

        var shouldSave: Bool {
            switch self {
            case .thisTimeOnly: false
            default: true
            }
        }

        var label: String {
            switch self {
            case .thisTimeOnly: "This time only"
            case .fifteenMinutes: "15 minutes"
            case .oneHour: "1 hour"
            case .fourHours: "4 hours"
            case .always: "Always"
            }
        }
    }

    private static func policyToDecision(_ policy: String) -> Decision {
        switch policy {
        case "allow": .allow
        case "deny": .deny
        default: .ask
        }
    }
}
