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
    private var notificationHandler: NIP46NotificationHandler?
    private var notificationTask: Task<Void, Never>?

    /// Callback invoked when an incoming request needs processing.
    /// Parameters: (senderPubkey, recipientIdentityPubkey, NIP46Request)
    private var onIncomingRequest: ((String, String, NIP46Request) -> Void)?

    /// Set the callback for incoming requests (must be called from outside the actor).
    func setOnIncomingRequest(_ handler: @escaping (String, String, NIP46Request) -> Void) {
        onIncomingRequest = handler
    }

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
            await client?.connect()

            // Start notification handler for streaming events
            if let client {
                startNotificationHandler(client: client)
            }

            // Subscribe for Kind 24133 events p-tagged to each of our identities
            for pubkeyHex in identityKeys.keys {
                if let pubkey = try? PublicKey.parse(publicKey: pubkeyHex) {
                    let filter = Filter()
                        .kind(kind: Kind(kind: 24133))
                        .pubkey(pubkey: pubkey)
                        .since(timestamp: Timestamp.now())
                    let _ = try? await client?.subscribe(filter: filter)
                }
            }

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

    // MARK: - Notification Handler

    private func startNotificationHandler(client: Client) {
        let handler = NIP46NotificationHandler()
        self.notificationHandler = handler

        // Wire the handler to route events back to this actor
        handler.onEvent = { [weak self] event in
            guard let self else { return }
            Task {
                await self.handleIncomingEvent(event)
            }
        }

        notificationTask = Task.detached { [handler] in
            do {
                try await client.handleNotifications(handler: handler)
            } catch {
                // handleNotifications exited — relay disconnected
            }
        }
    }

    /// Process an incoming Kind 24133 event.
    private func handleIncomingEvent(_ event: EventData) {
        let senderPubkey = event.pubkey
        let content = event.content

        // Find which identity this event is addressed to via p-tag
        // Only decrypt for identities we own — never brute-force all keys
        for pTag in event.pTags {
            guard identityKeys[pTag] != nil else { continue }
            if let request = decryptRequest(content: content, senderPubkey: senderPubkey, recipientIdentityPubkey: pTag) {
                onIncomingRequest?(senderPubkey, pTag, request)
                return
            }
        }
        // No matching p-tag for our identities — drop silently
    }
}

// MARK: - Event Data (lightweight struct for passing from handler)

struct EventData: Sendable {
    let pubkey: String
    let content: String
    let pTags: [String]
}

// MARK: - Notification Handler

/// Routes incoming relay events to the NIP46Service actor.
final class NIP46NotificationHandler: HandleNotification, @unchecked Sendable {
    var onEvent: ((EventData) -> Void)?

    func handleMsg(relayUrl: RelayUrl, msg: RelayMessage) async {}

    func handle(relayUrl: RelayUrl, subscriptionId: String, event: Event) async {
        // Only process Kind 24133 (NIP-46)
        guard event.kind().asU16() == 24133 else { return }

        // Extract data from rust-nostr Event into our Sendable struct
        let pubkey = event.author().toHex()
        let content = event.content()

        // Extract p-tags
        var pTags: [String] = []
        do {
            let tagVec = try event.tags().toVec()
            for tag in tagVec {
                let parts = try tag.asVec()
                if parts.count >= 2, parts[0] == "p" {
                    let pHex = parts[1]
                    // Validate hex pubkey format
                    if pHex.count == 64, pHex.allSatisfy(\.isHexDigit) {
                        pTags.append(pHex)
                    }
                }
            }
        } catch {
            // Tag parsing failed — still process event with empty pTags
        }

        let eventData = EventData(pubkey: pubkey, content: content, pTags: pTags)
        onEvent?(eventData)
    }
}
