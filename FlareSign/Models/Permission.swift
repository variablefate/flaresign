import Foundation
import SwiftData

/// A permission rule for a connected app.
///
/// Determines whether a specific NIP-46 method + event kind should be
/// auto-approved, denied, or presented to the user for manual approval.
@Model
final class Permission {
    /// NIP-46 method (e.g., "sign_event", "nip44_encrypt", "nip44_decrypt").
    var method: String

    /// Event kind number (for sign_event). Nil means all kinds for this method.
    var kind: Int?

    /// Policy: "allow", "deny", or "ask".
    var policy: String

    /// When this permission expires. Nil means permanent.
    var expiresAt: Date?

    /// The app this permission belongs to.
    var connectedApp: ConnectedApp?

    init(
        method: String,
        kind: Int? = nil,
        policy: String = "ask",
        expiresAt: Date? = nil
    ) {
        self.method = method
        self.kind = kind
        self.policy = policy
        self.expiresAt = expiresAt
    }

    /// Whether this permission has expired.
    var isExpired: Bool {
        guard let expiresAt else { return false }
        return Date.now > expiresAt
    }
}
