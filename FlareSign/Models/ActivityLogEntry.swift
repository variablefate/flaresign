import Foundation
import SwiftData

/// A record of a NIP-46 signing request for the activity audit log.
@Model
final class ActivityLogEntry {
    /// Unique identifier.
    @Attribute(.unique) var id: UUID

    /// Name of the app that made the request.
    var appName: String

    /// ID of the connected app (for filtering).
    var appId: UUID

    /// NIP-46 method (e.g., "sign_event", "nip44_encrypt").
    var method: String

    /// Event kind number (for sign_event), if applicable.
    var kind: Int?

    /// Whether the request was approved (true) or denied (false).
    var approved: Bool

    /// When the request was processed.
    var timestamp: Date

    /// Truncated event content for audit review (first 200 chars).
    var eventPreview: String?

    init(
        id: UUID = UUID(),
        appName: String,
        appId: UUID,
        method: String,
        kind: Int? = nil,
        approved: Bool,
        timestamp: Date = .now,
        eventPreview: String? = nil
    ) {
        self.id = id
        self.appName = appName
        self.appId = appId
        self.method = method
        self.kind = kind
        self.approved = approved
        self.timestamp = timestamp
        self.eventPreview = eventPreview
    }
}
