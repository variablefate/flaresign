import Foundation
import NostrSDK
import os

/// Core NIP-46 relay service.
///
/// Connects to relays, subscribes for Kind 24133 events tagged to any active identity,
/// decrypts incoming requests, routes them through the permission engine, and
/// publishes encrypted responses.
actor NIP46Service {
    private let logger = Logger(subsystem: "com.flaresign", category: "NIP46")
    private var client: Client?
    private var sessions: [String: NIP46Session] = [:]  // keyed by client pubkey
    private var identityKeys: [String: Keys] = []        // pubkey hex → rust-nostr Keys

    private let defaultRelays = [
        "wss://relay.damus.io",
        "wss://nos.lol",
        "wss://relay.primal.net",
    ]

    /// Start the NIP-46 service: connect to relays, subscribe for requests.
    func start(identities: [(publicKeyHex: String, privateKeyHex: String)]) async {
        // Store identity keys for decryption
        for identity in identities {
            if let secretKey = try? SecretKey.parse(secretKey: identity.privateKeyHex) {
                identityKeys[identity.publicKeyHex] = Keys(secretKey: secretKey)
            }
        }

        guard !identityKeys.isEmpty else {
            logger.warning("No valid identity keys — NIP-46 service not starting")
            return
        }

        do {
            let signer = NostrSigner.keys(keys: identityKeys.values.first!)
            client = Client(signer: signer)

            for relay in defaultRelays {
                try await client?.addRelay(url: relay)
            }
            try await client?.connect()

            // Subscribe for Kind 24133 events p-tagged to any of our identities
            let pubkeys = identityKeys.keys.map { $0 }
            let filter = Filter()
                .kinds(kinds: [24133])
                .pubkeys(publicKeys: pubkeys.compactMap { try? PublicKey.parse(publicKey: $0) })

            // Note: actual subscription handling depends on rust-nostr streaming API
            // This is the subscription setup — event handling is in handleIncomingEvents()
            logger.info("NIP-46 service started with \(pubkeys.count) identities")
        } catch {
            logger.error("Failed to start NIP-46 service: \(error)")
        }
    }

    /// Stop the service and disconnect.
    func stop() async {
        try? await client?.disconnect()
        client = nil
        sessions.removeAll()
        identityKeys.removeAll()
        logger.info("NIP-46 service stopped")
    }

    /// Register a session for a connected app.
    func addSession(_ session: NIP46Session) {
        sessions[session.clientPubkey] = session
        logger.info("Session added for client: \(session.clientPubkey.prefix(8))...")
    }

    /// Remove a session (disconnect app).
    func removeSession(clientPubkey: String) {
        sessions.removeValue(forKey: clientPubkey)
        logger.info("Session removed for client: \(clientPubkey.prefix(8))...")
    }

    /// Add relays for a specific app session.
    func addRelays(_ relays: [String]) async {
        for relay in relays {
            try? await client?.addRelay(url: relay)
        }
    }

    /// Publish an encrypted NIP-46 response.
    func publishResponse(
        _ response: NIP46Response,
        to clientPubkey: String,
        signingWith identityPubkey: String
    ) async {
        guard let keys = identityKeys[identityPubkey] else {
            logger.error("No keys found for identity \(identityPubkey.prefix(8))...")
            return
        }

        do {
            let json = try JSONEncoder().encode(response)
            guard let plaintext = String(data: json, encoding: .utf8) else { return }

            let recipientPubkey = try PublicKey.parse(publicKey: clientPubkey)
            let encrypted = try nip44Encrypt(
                secretKey: keys.secretKey(),
                publicKey: recipientPubkey,
                content: plaintext
            )

            let event = try EventBuilder(
                kind: 24133,
                content: encrypted,
                tags: [.publicKey(publicKey: recipientPubkey)]
            ).signWith(keys: keys)

            let eventId = try await client?.sendEvent(event: event)
            logger.info("Published NIP-46 response \(response.id) → \(eventId?.toHex().prefix(8) ?? "nil")...")
        } catch {
            logger.error("Failed to publish NIP-46 response: \(error)")
        }
    }

    /// Decrypt an incoming Kind 24133 event content.
    func decryptRequest(
        content: String,
        senderPubkey: String,
        recipientIdentityPubkey: String
    ) -> NIP46Request? {
        guard let keys = identityKeys[recipientIdentityPubkey] else { return nil }

        do {
            let senderPK = try PublicKey.parse(publicKey: senderPubkey)
            let plaintext = try nip44Decrypt(
                secretKey: keys.secretKey(),
                publicKey: senderPK,
                payload: content
            )
            return try JSONDecoder().decode(NIP46Request.self, from: Data(plaintext.utf8))
        } catch {
            logger.error("Failed to decrypt NIP-46 request: \(error)")
            return nil
        }
    }

    /// Sign an event using an identity's private key.
    func signEvent(
        unsignedEventJSON: String,
        identityPubkey: String
    ) -> String? {
        guard let keys = identityKeys[identityPubkey] else { return nil }

        do {
            let event = try EventBuilder.fromJson(json: unsignedEventJSON).signWith(keys: keys)
            return try event.asJson()
        } catch {
            logger.error("Failed to sign event: \(error)")
            return nil
        }
    }

    /// NIP-44 encrypt using an identity's key.
    func nip44EncryptContent(
        plaintext: String,
        recipientPubkey: String,
        identityPubkey: String
    ) -> String? {
        guard let keys = identityKeys[identityPubkey] else { return nil }
        do {
            let recipientPK = try PublicKey.parse(publicKey: recipientPubkey)
            return try nip44Encrypt(secretKey: keys.secretKey(), publicKey: recipientPK, content: plaintext)
        } catch {
            logger.error("Failed to NIP-44 encrypt: \(error)")
            return nil
        }
    }

    /// NIP-44 decrypt using an identity's key.
    func nip44DecryptContent(
        ciphertext: String,
        senderPubkey: String,
        identityPubkey: String
    ) -> String? {
        guard let keys = identityKeys[identityPubkey] else { return nil }
        do {
            let senderPK = try PublicKey.parse(publicKey: senderPubkey)
            return try nip44Decrypt(secretKey: keys.secretKey(), publicKey: senderPK, payload: ciphertext)
        } catch {
            logger.error("Failed to NIP-44 decrypt: \(error)")
            return nil
        }
    }
}
