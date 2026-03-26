import Foundation
import SwiftData
import NostrPasskey
import os

/// Root application state for FlareSign.
@MainActor @Observable
final class AppState {
    private let logger = Logger(subsystem: "com.flaresign", category: "AppState")

    // MARK: - Auth State

    enum AuthState {
        case loading
        case onboarding
        case ready
    }

    var authState: AuthState = .loading

    // MARK: - Dependencies

    var identityManager: IdentityManager?
    var modelContext: ModelContext?
    let passkeyManager = NostrPasskeyManager(relyingPartyID: "roadflare.app")
    let nip46Service = NIP46Service()
    let requestQueue = RequestQueue()

    // MARK: - State

    var identities: [Identity] = []
    var connectedApps: [ConnectedApp] = []
    var selectedIdentity: Identity?

    // MARK: - Setup

    private var isSetUp = false

    func setup(modelContext: ModelContext) {
        guard !isSetUp else { return }
        isSetUp = true
        self.modelContext = modelContext
        identityManager = IdentityManager(modelContext: modelContext, passkeyManager: passkeyManager)
        loadIdentities()
        loadConnectedApps()
        wireRequestHandler()
    }

    func loadIdentities() {
        guard let manager = identityManager else { return }
        do {
            identities = try manager.listIdentities()
            authState = identities.isEmpty ? .onboarding : .ready
            if selectedIdentity == nil { selectedIdentity = identities.first }
        } catch {
            authState = .onboarding
        }
    }

    func loadConnectedApps() {
        guard let ctx = modelContext else { return }
        do {
            let descriptor = FetchDescriptor<ConnectedApp>(sortBy: [SortDescriptor(\.lastUsedAt, order: .reverse)])
            connectedApps = try ctx.fetch(descriptor)
        } catch {
            logger.error("Failed to load connected apps: \(error)")
        }
    }

    // MARK: - Identity Actions

    @available(iOS 18.0, *)
    func createIdentityWithPasskey(label: String) async throws {
        guard let manager = identityManager else { return }
        let index = try manager.nextPasskeyIndex()
        let identity = try await manager.createWithPasskey(index: index, label: label)
        identities.append(identity)
        selectedIdentity = identity
        authState = .ready
    }

    func importIdentity(nsec: String, label: String) throws {
        guard let manager = identityManager else { return }
        let identity = try manager.importNsec(nsec, label: label)
        identities.append(identity)
        selectedIdentity = identity
        authState = .ready
    }

    func deleteIdentity(_ identity: Identity) {
        identityManager?.deleteIdentity(identity)
        identities.removeAll { $0.publicKeyHex == identity.publicKeyHex }
        if selectedIdentity?.publicKeyHex == identity.publicKeyHex {
            selectedIdentity = identities.first
        }
        if identities.isEmpty {
            authState = .onboarding
        }
    }

    // MARK: - Connect App

    /// Approve a nostrconnect:// connection and wire up the NIP-46 session.
    func approveConnection(_ params: NostrConnectParams, forIdentity identity: Identity) async {
        guard let ctx = modelContext else { return }

        // Create ConnectedApp in SwiftData
        let app = ConnectedApp(
            name: params.name ?? "Unknown App",
            iconURL: params.image,
            clientPubkey: params.clientPubkey,
            relays: params.relays,
            secret: params.secret
        )
        app.identity = identity
        ctx.insert(app)
        try? ctx.save()
        connectedApps.append(app)

        // Create NIP-46 session
        let session = NIP46Session(
            clientPubkey: params.clientPubkey,
            identityPubkey: identity.publicKeyHex,
            appId: app.id,
            appName: app.name
        )
        await nip46Service.addSession(session)
        await nip46Service.addRelays(params.relays)

        // Send connect response (with secret if provided)
        let connectResponse = NIP46Response.success(
            id: "connect",
            result: params.secret ?? "ack"
        )
        await nip46Service.publishResponse(
            connectResponse,
            to: params.clientPubkey,
            signingWith: identity.publicKeyHex
        )

        logger.info("Connected app: \(app.name) → identity \(identity.label)")
    }

    /// Disconnect and remove a connected app.
    func disconnectApp(_ app: ConnectedApp) async {
        guard let ctx = modelContext else { return }
        await nip46Service.removeSession(clientPubkey: app.clientPubkey)
        ctx.delete(app)
        try? ctx.save()
        connectedApps.removeAll { $0.id == app.id }
    }

    // MARK: - NIP-46 Lifecycle

    func startNIP46Service() async {
        let keyPairs: [(publicKeyHex: String, privateKeyHex: String)] = identities.compactMap { identity in
            guard let privKey = KeychainStore.load(for: identity.publicKeyHex) else {
                logger.warning("Missing Keychain entry for identity \(identity.label)")
                return nil
            }
            return (publicKeyHex: identity.publicKeyHex, privateKeyHex: privKey)
        }
        await nip46Service.start(identities: keyPairs)

        // Restore sessions for existing connected apps
        for app in connectedApps {
            guard let identityPubkey = app.identity?.publicKeyHex else { continue }
            let session = NIP46Session(
                clientPubkey: app.clientPubkey,
                identityPubkey: identityPubkey,
                appId: app.id,
                appName: app.name
            )
            await nip46Service.addSession(session)
        }

        // Wire incoming request handler
        await nip46Service.setOnIncomingRequest { [weak self] senderPubkey, identityPubkey, request in
            guard let self else { return }
            Task { @MainActor in
                self.handleIncomingNIP46Request(senderPubkey: senderPubkey, identityPubkey: identityPubkey, request: request)
            }
        }
    }

    func stopNIP46Service() async {
        await nip46Service.stop()
    }

    // MARK: - Incoming Request Handling

    /// Called when the NIP-46 service receives a decrypted request from a relay.
    private func handleIncomingNIP46Request(senderPubkey: String, identityPubkey: String, request: NIP46Request) {
        // Find the session for this sender
        guard let app = connectedApps.first(where: { $0.clientPubkey == senderPubkey }) else {
            logger.info("Ignoring request from unknown client: \(senderPubkey.prefix(8))...")
            return
        }

        // Extract event kind if sign_event
        let kind: Int? = {
            guard request.method == "sign_event", let json = request.params.first,
                  let data = json.data(using: .utf8),
                  let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
            return dict["kind"] as? Int
        }()

        // Check permissions
        let decision = PermissionEngine.evaluate(method: request.method, kind: kind, permissions: app.permissions)

        switch decision {
        case .allow:
            // Auto-approve: execute and respond immediately
            Task {
                let session = NIP46Session(
                    clientPubkey: senderPubkey,
                    identityPubkey: identityPubkey,
                    appId: app.id,
                    appName: app.name
                )
                let response = await session.executeRequest(request, nip46Service: nip46Service)
                await nip46Service.publishResponse(response, to: senderPubkey, signingWith: identityPubkey)

                // Log
                if let ctx = modelContext {
                    let entry = ActivityLogEntry(
                        appName: app.name, appId: app.id,
                        method: request.method, kind: kind, approved: true,
                        eventPreview: request.params.first.map { String($0.prefix(200)) }
                    )
                    ctx.insert(entry)
                    try? ctx.save()
                }
                app.lastUsedAt = .now
                try? modelContext?.save()
            }

        case .deny:
            // Auto-deny: respond with error
            Task {
                let response = NIP46Response.error(id: request.id, message: "Denied by policy")
                await nip46Service.publishResponse(response, to: senderPubkey, signingWith: identityPubkey)

                if let ctx = modelContext {
                    let entry = ActivityLogEntry(
                        appName: app.name, appId: app.id,
                        method: request.method, kind: kind, approved: false
                    )
                    ctx.insert(entry)
                    try? ctx.save()
                }
            }

        case .ask:
            // Queue for manual approval
            let contentPreview: String? = {
                guard let json = request.params.first,
                      let data = json.data(using: .utf8),
                      let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
                return (dict["content"] as? String).map { String($0.prefix(200)) }
            }()

            let pending = PendingRequest(
                id: request.id,
                appName: app.name,
                appId: app.id,
                clientPubkey: senderPubkey,
                method: request.method,
                kind: kind,
                contentPreview: contentPreview,
                rawParams: request.params,
                receivedAt: .now
            )
            requestQueue.enqueue(pending)
        }
    }

    // MARK: - Request Handler Wiring

    private func wireRequestHandler() {
        requestQueue.onResponse { [weak self] requestId, approved, remember in
            guard let self else { return }
            Task { @MainActor in
                await self.handleRequestResponse(requestId: requestId, approved: approved, remember: remember)
            }
        }
    }

    /// Handle user's approval/denial of a pending request.
    private func handleRequestResponse(
        requestId: String,
        approved: Bool,
        remember: PermissionEngine.RememberDuration?
    ) async {
        guard let request = findPendingRequest(requestId) else { return }
        guard let ctx = modelContext else { return }

        // Find the session
        let session = connectedApps.first(where: { $0.id == request.appId })
        guard let identityPubkey = session?.identity?.publicKeyHex else { return }

        // Execute or deny
        let response: NIP46Response
        if approved {
            // Re-create NIP46Session to execute
            let nip46Session = NIP46Session(
                clientPubkey: request.clientPubkey,
                identityPubkey: identityPubkey,
                appId: request.appId,
                appName: request.appName
            )
            response = await nip46Session.executeRequest(
                NIP46Request(id: requestId, method: request.method, params: request.rawParams),
                nip46Service: nip46Service
            )
        } else {
            response = .error(id: requestId, message: "User denied request")
        }

        // Publish response
        await nip46Service.publishResponse(response, to: request.clientPubkey, signingWith: identityPubkey)

        // Log activity
        let logEntry = ActivityLogEntry(
            appName: request.appName,
            appId: request.appId,
            method: request.method,
            kind: request.kind,
            approved: approved,
            eventPreview: request.contentPreview
        )
        ctx.insert(logEntry)
        try? ctx.save()

        // Save permission if "remember" was set
        if let remember, remember.shouldSave {
            if let app = connectedApps.first(where: { $0.id == request.appId }) {
                let perm = Permission(
                    method: request.method,
                    kind: request.kind,
                    policy: approved ? "allow" : "deny",
                    expiresAt: remember.expiresAt
                )
                perm.connectedApp = app
                ctx.insert(perm)
                try? ctx.save()
            }
        }

        // Update lastUsedAt
        if let app = connectedApps.first(where: { $0.id == request.appId }) {
            app.lastUsedAt = .now
            try? ctx.save()
        }
    }

    /// Find a pending request by ID (searches current + queue indirectly via stored data).
    private func findPendingRequest(_ requestId: String) -> PendingRequest? {
        if requestQueue.currentRequest?.id == requestId {
            return requestQueue.currentRequest
        }
        return nil
    }
}
