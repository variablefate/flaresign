import Foundation

/// NIP-46 JSON-RPC request from a client app.
struct NIP46Request: Codable, Sendable {
    let id: String
    let method: String
    let params: [String]
}

/// NIP-46 JSON-RPC response from the signer.
struct NIP46Response: Codable, Sendable {
    let id: String
    let result: String?
    let error: String?

    init(id: String, result: String? = nil, error: String? = nil) {
        self.id = id
        self.result = result
        self.error = error
    }

    /// Convenience: success response.
    static func success(id: String, result: String) -> NIP46Response {
        NIP46Response(id: id, result: result)
    }

    /// Convenience: error response.
    static func error(id: String, message: String) -> NIP46Response {
        NIP46Response(id: id, error: message)
    }
}

/// Parsed parameters from a `nostrconnect://` URI.
struct NostrConnectParams: Sendable {
    let clientPubkey: String
    let relays: [String]
    let secret: String?
    let name: String?
    let url: String?
    let image: String?
    let permissions: [String]
}

/// Parsed parameters from a `bunker://` URI.
struct BunkerParams: Sendable {
    let signerPubkey: String
    let relays: [String]
    let secret: String?
}

/// Human-readable names for common Nostr event kinds.
enum EventKindLabel {
    static func name(for kind: Int) -> String {
        switch kind {
        case 0: "Profile Metadata"
        case 1: "Short Text Note"
        case 3: "Contact List"
        case 4: "Encrypted DM (NIP-04)"
        case 5: "Event Deletion"
        case 6: "Repost"
        case 7: "Reaction"
        case 8: "Badge Award"
        case 10002: "Relay List"
        case 22242: "Relay Auth"
        case 30023: "Long-Form Article"
        default: "Kind \(kind)"
        }
    }
}
