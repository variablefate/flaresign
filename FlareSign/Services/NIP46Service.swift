import Foundation
import NostrSDK
import os

/// Core NIP-46 relay service.
///
/// Connects to relays, subscribes for Kind 24133 events tagged to any active identity,
/// decrypts incoming requests, routes them through sessions.
actor NIP46Service {
    private let logger = Logger(subsystem: "com.flaresign", category: "NIP46")
    private var client: Client?
    private var sessions: [String: NIP46Session] = [:]  // keyed by client pubkey
    private var identityKeys: [String: Keys] = [:]       // pubkey hex → rust-nostr Keys

    private let defaultRelays = [
        "wss://relay.damus.io",
        "wss://nos.lol",
        "wss://relay.primal.net",
    ]

    // MARK: - Lifecycle

    func start(identities: [(publicKeyHex: String, privateKeyHex: String)]) async {
        for identity in identities {
            if let secretKey = try? SecretKey.parse(secretKey: identity.privateKeyHex) {
                identityKeys[identity.publicKeyHex] = Keys(secretKey: secretKey)
            }
        }

        guard let firstKeys = identityKeys.values.first else {
            logger.warning("No valid identity keys — NIP-46 service not starting")
            return
        }

        do {
            let signer = NostrSigner.keys(keys: firstKeys)
            client = Client(signer: signer)

            for relay in defaultRelays {
                let relayUrl = try RelayUrl.parse(url: relay)
                try await client?.addRelay(url: relayUrl)
            }
            try await client?.connect()
            logger.info("NIP-46 service started with \(self.identityKeys.count) identities")
        } catch {
            logger.error("Failed to start NIP-46 service: \(error)")
        }
    }

    func stop() async {
        try? await client?.disconnect()
        client = nil
        sessions.removeAll()
        identityKeys.removeAll()
        logger.info("NIP-46 service stopped")
    }

    // MARK: - Session Management

    func addSession(_ session: NIP46Session) {
        sessions[session.clientPubkey] = session
        logger.info("Session added for client: \(session.clientPubkey.prefix(8))...")
    }

    func removeSession(clientPubkey: String) {
        sessions.removeValue(forKey: clientPubkey)
        logger.info("Session removed for client: \(clientPubkey.prefix(8))...")
    }

    func addRelays(_ relays: [String]) async {
        for relay in relays {
            if let relayUrl = try? RelayUrl.parse(url: relay) {
                try? await client?.addRelay(url: relayUrl)
            }
        }
    }

    // MARK: - Publish Response

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
                content: plaintext,
                version: .v2
            )

            let tag = try Tag.parse(data: ["p", clientPubkey])
            let builder = EventBuilder(kind: Kind(kind: 24133), content: encrypted)
                .tags(tags: [tag])

            let signer = NostrSigner.keys(keys: keys)
            let event = try await builder.sign(signer: signer)
            let output = try await client?.sendEvent(event: event)
            logger.info("Published NIP-46 response \(response.id)")
        } catch {
            logger.error("Failed to publish NIP-46 response: \(error)")
        }
    }

    // MARK: - Decrypt

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

    // MARK: - Sign Event

    func signEvent(
        unsignedEventJSON: String,
        identityPubkey: String
    ) async -> String? {
        guard let keys = identityKeys[identityPubkey] else { return nil }

        do {
            // Parse the unsigned event JSON to extract kind, content, tags
            guard let data = unsignedEventJSON.data(using: .utf8),
                  let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let kindNum = dict["kind"] as? Int,
                  let content = dict["content"] as? String else {
                logger.error("Failed to parse unsigned event JSON")
                return nil
            }

            let tagArrays = dict["tags"] as? [[String]] ?? []
            var tags: [Tag] = []
            for tagArray in tagArrays {
                if let tag = try? Tag.parse(data: tagArray) {
                    tags.append(tag)
                }
            }

            let builder = EventBuilder(kind: Kind(kind: UInt16(kindNum)), content: content)
                .tags(tags: tags)

            let signer = NostrSigner.keys(keys: keys)
            let signedEvent = try await builder.sign(signer: signer)
            return try signedEvent.asJson()
        } catch {
            logger.error("Failed to sign event: \(error)")
            return nil
        }
    }

    // MARK: - NIP-44 Encrypt/Decrypt

    func nip44EncryptContent(
        plaintext: String,
        recipientPubkey: String,
        identityPubkey: String
    ) -> String? {
        guard let keys = identityKeys[identityPubkey] else { return nil }
        do {
            let recipientPK = try PublicKey.parse(publicKey: recipientPubkey)
            return try nip44Encrypt(secretKey: keys.secretKey(), publicKey: recipientPK, content: plaintext, version: .v2)
        } catch {
            logger.error("Failed to NIP-44 encrypt: \(error)")
            return nil
        }
    }

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
