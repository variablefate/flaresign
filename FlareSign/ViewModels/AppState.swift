import Foundation
import SwiftData
import NostrPasskey

/// Root application state for FlareSign.
@MainActor @Observable
final class AppState {
    // MARK: - Auth State

    enum AuthState {
        case loading
        case onboarding
        case ready
    }

    var authState: AuthState = .loading

    // MARK: - Dependencies

    var identityManager: IdentityManager?
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
        identityManager = IdentityManager(modelContext: modelContext, passkeyManager: passkeyManager)
        loadIdentities()

        // Wire up request queue response handler
        requestQueue.onResponse { [weak self] requestId, approved, remember in
            // TODO: Phase 2 — save permission if remember is set, publish response
            _ = self
        }
    }

    func loadIdentities() {
        guard let manager = identityManager else { return }
        do {
            identities = try manager.listIdentities()
            authState = identities.isEmpty ? .onboarding : .ready
            selectedIdentity = identities.first
        } catch {
            authState = .onboarding
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

    // MARK: - NIP-46 Lifecycle

    func startNIP46Service() async {
        guard let manager = identityManager else { return }
        let keyPairs: [(publicKeyHex: String, privateKeyHex: String)] = identities.compactMap { identity in
            guard let privKey = KeychainStore.load(for: identity.publicKeyHex) else { return nil }
            return (publicKeyHex: identity.publicKeyHex, privateKeyHex: privKey)
        }
        await nip46Service.start(identities: keyPairs)
    }

    func stopNIP46Service() async {
        await nip46Service.stop()
    }
}
