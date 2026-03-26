import Foundation
import SwiftData

/// A Nostr identity managed by the signer.
///
/// The private key is stored in iOS Keychain (keyed by `publicKeyHex`),
/// never in SwiftData.
@Model
final class Identity {
    /// Public key in hex format (64 characters). Unique identifier.
    @Attribute(.unique) var publicKeyHex: String

    /// Public key in NIP-19 bech32 format (npub1...).
    var npub: String

    /// User-defined label (e.g., "Personal", "Work", "Anon").
    var label: String

    /// Passkey derivation index. -1 for imported keys (not passkey-derived).
    var index: Int

    /// Whether this key was derived from a passkey (vs manually imported).
    var isPasskeyDerived: Bool

    /// When this identity was created.
    var createdAt: Date

    /// Apps connected to this identity.
    @Relationship(deleteRule: .cascade, inverse: \ConnectedApp.identity)
    var connectedApps: [ConnectedApp] = []

    init(
        publicKeyHex: String,
        npub: String,
        label: String,
        index: Int,
        isPasskeyDerived: Bool,
        createdAt: Date = .now
    ) {
        self.publicKeyHex = publicKeyHex
        self.npub = npub
        self.label = label
        self.index = index
        self.isPasskeyDerived = isPasskeyDerived
        self.createdAt = createdAt
    }
}
