import Foundation

/// A NIP-46 session with a specific connected client app.
///
/// Routes incoming requests through the permission engine and
/// either auto-responds or queues for manual user approval.
final class NIP46Session: Sendable {
    let clientPubkey: String
    let identityPubkey: String
    let appId: UUID
    let appName: String

    init(clientPubkey: String, identityPubkey: String, appId: UUID, appName: String) {
        self.clientPubkey = clientPubkey
        self.identityPubkey = identityPubkey
        self.appId = appId
        self.appName = appName
    }

    /// Process an incoming NIP-46 request.
    ///
    /// Returns a response immediately for auto-approved methods, or nil if the request
    /// needs to be queued for manual approval.
    func processRequest(
        _ request: NIP46Request,
        permissions: [Permission],
        nip46Service: NIP46Service
    ) async -> NIP46Response? {
        let kind = extractKind(from: request)
        let decision = PermissionEngine.evaluate(
            method: request.method,
            kind: kind,
            permissions: permissions
        )

        switch decision {
        case .allow:
            return await executeRequest(request, nip46Service: nip46Service)
        case .deny:
            return .error(id: request.id, message: "Request denied by policy")
        case .ask:
            return nil  // caller should queue for manual approval
        }
    }

    /// Execute an approved request and produce a response.
    func executeRequest(
        _ request: NIP46Request,
        nip46Service: NIP46Service
    ) async -> NIP46Response {
        switch request.method {
        case "ping":
            return .success(id: request.id, result: "pong")

        case "get_public_key":
            return .success(id: request.id, result: identityPubkey)

        case "connect":
            return .success(id: request.id, result: "ack")

        case "sign_event":
            guard let eventJSON = request.params.first else {
                return .error(id: request.id, message: "Missing event parameter")
            }
            if let signed = await nip46Service.signEvent(
                unsignedEventJSON: eventJSON,
                identityPubkey: identityPubkey
            ) {
                return .success(id: request.id, result: signed)
            } else {
                return .error(id: request.id, message: "Failed to sign event")
            }

        case "nip44_encrypt":
            guard request.params.count >= 2 else {
                return .error(id: request.id, message: "Missing parameters (pubkey, plaintext)")
            }
            if let encrypted = await nip46Service.nip44EncryptContent(
                plaintext: request.params[1],
                recipientPubkey: request.params[0],
                identityPubkey: identityPubkey
            ) {
                return .success(id: request.id, result: encrypted)
            } else {
                return .error(id: request.id, message: "Encryption failed")
            }

        case "nip44_decrypt":
            guard request.params.count >= 2 else {
                return .error(id: request.id, message: "Missing parameters (pubkey, ciphertext)")
            }
            if let decrypted = await nip46Service.nip44DecryptContent(
                ciphertext: request.params[1],
                senderPubkey: request.params[0],
                identityPubkey: identityPubkey
            ) {
                return .success(id: request.id, result: decrypted)
            } else {
                return .error(id: request.id, message: "Decryption failed")
            }

        default:
            return .error(id: request.id, message: "Unsupported method: \(request.method)")
        }
    }

    /// Extract the event kind from a sign_event request's params.
    private func extractKind(from request: NIP46Request) -> Int? {
        guard request.method == "sign_event", let eventJSON = request.params.first else { return nil }
        guard let data = eventJSON.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let kind = dict["kind"] as? Int else { return nil }
        return kind
    }
}
