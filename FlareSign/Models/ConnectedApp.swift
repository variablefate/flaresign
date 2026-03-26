import Foundation
import SwiftData

/// A client app connected via NIP-46 (Nostr Connect).
@Model
final class ConnectedApp {
    /// Unique identifier.
    @Attribute(.unique) var id: UUID

    /// App name (from nostrconnect:// name param or user-entered).
    var name: String

    /// App icon URL (from nostrconnect:// image param), if available.
    var iconURL: String?

    /// The ephemeral client pubkey used for NIP-46 encrypted communication.
    var clientPubkey: String

    /// Relay URLs used for this NIP-46 session.
    var relays: [String]

    /// The nostrconnect:// secret (used to verify first connect response).
    var secret: String?

    /// When the app was first connected.
    var connectedAt: Date

    /// When the app last sent a signing request.
    var lastUsedAt: Date

    /// The identity this app is bound to.
    var identity: Identity?

    /// Per-app permissions.
    @Relationship(deleteRule: .cascade, inverse: \Permission.connectedApp)
    var permissions: [Permission] = []

    init(
        id: UUID = UUID(),
        name: String,
        iconURL: String? = nil,
        clientPubkey: String,
        relays: [String],
        secret: String? = nil,
        connectedAt: Date = .now,
        lastUsedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.iconURL = iconURL
        self.clientPubkey = clientPubkey
        self.relays = relays
        self.secret = secret
        self.connectedAt = connectedAt
        self.lastUsedAt = lastUsedAt
    }
}
