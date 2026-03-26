import Foundation

/// Parses NIP-46 connection URIs.
enum NIP46URIParser {

    /// Parse a `nostrconnect://` URI (client-initiated connection).
    ///
    /// Format: `nostrconnect://<client-pubkey>?relay=wss://...&secret=abc&name=AppName&perms=sign_event:1`
    static func parseNostrConnect(_ uri: String) -> NostrConnectParams? {
        guard uri.hasPrefix("nostrconnect://") else { return nil }

        // URLComponents needs a scheme, nostrconnect:// has the pubkey as "host"
        let normalized = uri.replacingOccurrences(of: "nostrconnect://", with: "nostrconnect://host/")
        guard let url = URL(string: uri) else { return nil }

        // Extract client pubkey (the "host" portion)
        let afterScheme = uri.dropFirst("nostrconnect://".count)
        let clientPubkey = String(afterScheme.prefix(while: { $0 != "?" && $0 != "/" }))
        guard clientPubkey.count == 64, clientPubkey.allSatisfy(\.isHexDigit) else { return nil }

        // Parse query parameters
        let components = URLComponents(string: normalized)
        let queryItems = components?.queryItems ?? []

        let relays = queryItems.filter { $0.name == "relay" }
            .compactMap(\.value)
            .filter { $0.hasPrefix("wss://") || $0.hasPrefix("ws://") }
        let secret = queryItems.first(where: { $0.name == "secret" })?.value
        let name = queryItems.first(where: { $0.name == "name" })?.value
        let appURL = queryItems.first(where: { $0.name == "url" })?.value
        let image = queryItems.first(where: { $0.name == "image" })?.value
        let permsString = queryItems.first(where: { $0.name == "perms" })?.value
        let permissions = permsString?.components(separatedBy: ",").filter { !$0.isEmpty } ?? []

        guard !relays.isEmpty else { return nil }

        _ = url // suppress unused warning

        return NostrConnectParams(
            clientPubkey: clientPubkey,
            relays: relays,
            secret: secret,
            name: name,
            url: appURL,
            image: image,
            permissions: permissions
        )
    }

    /// Parse a `bunker://` URI (signer-initiated connection).
    ///
    /// Format: `bunker://<signer-pubkey>?relay=wss://...&relay=wss://...&secret=abc`
    static func parseBunker(_ uri: String) -> BunkerParams? {
        guard uri.hasPrefix("bunker://") else { return nil }

        let afterScheme = uri.dropFirst("bunker://".count)
        let signerPubkey = String(afterScheme.prefix(while: { $0 != "?" && $0 != "/" }))
        guard signerPubkey.count == 64, signerPubkey.allSatisfy(\.isHexDigit) else { return nil }

        let normalized = uri.replacingOccurrences(of: "bunker://", with: "bunker://host/")
        let components = URLComponents(string: normalized)
        let queryItems = components?.queryItems ?? []

        let relays = queryItems.filter { $0.name == "relay" }
            .compactMap(\.value)
            .filter { $0.hasPrefix("wss://") || $0.hasPrefix("ws://") }
        let secret = queryItems.first(where: { $0.name == "secret" })?.value

        guard !relays.isEmpty else { return nil }

        return BunkerParams(
            signerPubkey: signerPubkey,
            relays: relays,
            secret: secret
        )
    }

    /// Generate a `bunker://` URI for sharing with client apps.
    static func generateBunkerURI(
        signerPubkey: String,
        relays: [String],
        secret: String? = nil
    ) -> String {
        var components = URLComponents()
        components.scheme = "bunker"
        components.host = signerPubkey

        var queryItems = relays.map { URLQueryItem(name: "relay", value: $0) }
        if let secret {
            queryItems.append(URLQueryItem(name: "secret", value: secret))
        }
        components.queryItems = queryItems.isEmpty ? nil : queryItems

        // URLComponents encodes the host incorrectly for this scheme, build manually
        let relayParams = relays.map { "relay=\($0.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0)" }
        var params = relayParams
        if let secret { params.append("secret=\(secret)") }
        return "bunker://\(signerPubkey)?\(params.joined(separator: "&"))"
    }
}
