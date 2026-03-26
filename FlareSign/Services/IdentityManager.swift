import Foundation
import SwiftData
import NostrPasskey

/// Manages identity lifecycle: create, import, delete, recover.
///
/// Private keys are stored in iOS Keychain via `KeychainStore`.
/// Public identity metadata is stored in SwiftData.
@MainActor
final class IdentityManager {
    private let modelContext: ModelContext
    private let passkeyManager: NostrPasskeyManager

    init(modelContext: ModelContext, passkeyManager: NostrPasskeyManager) {
        self.modelContext = modelContext
        self.passkeyManager = passkeyManager
    }

    // MARK: - Create

    /// Create a new identity via passkey at the given index.
    @available(iOS 18.0, *)
    func createWithPasskey(index: Int, label: String) async throws -> Identity {
        let keypair: NostrPasskeyKeypair
        if index == 0 {
            // First identity — register a new passkey
            keypair = try await passkeyManager.createPasskeyAndDeriveIndexedKey(index: 0)
        } else {
            // Additional identity — authenticate existing passkey with new index
            keypair = try await passkeyManager.deriveIndexedKey(index: index)
        }
        return try saveIdentity(keypair: keypair, label: label, index: index, isPasskeyDerived: true)
    }

    /// Import an identity from an nsec string.
    func importNsec(_ nsec: String, label: String) throws -> Identity {
        let keypair = try NostrPasskeyKeypair.fromNsec(nsec)
        return try saveIdentity(keypair: keypair, label: label, index: -1, isPasskeyDerived: false)
    }

    // MARK: - Recover

    /// Recover all indexed identities from passkey.
    ///
    /// Authenticates once per index. Stops when derivation produces a key
    /// not already in the identity store (assumes contiguous indices).
    @available(iOS 18.0, *)
    func recoverFromPasskey(knownCount: Int) async throws -> [Identity] {
        var recovered: [Identity] = []
        for i in 0..<knownCount {
            let keypair = try await passkeyManager.deriveIndexedKey(index: i)
            // Check if already exists
            let pubkey = keypair.publicKeyHex
            let descriptor = FetchDescriptor<Identity>(predicate: #Predicate { $0.publicKeyHex == pubkey })
            let existing = try modelContext.fetch(descriptor)
            if existing.isEmpty {
                let identity = try saveIdentity(
                    keypair: keypair,
                    label: "Identity \(i)",
                    index: i,
                    isPasskeyDerived: true
                )
                recovered.append(identity)
            }
        }
        return recovered
    }

    // MARK: - Delete

    /// Delete an identity and its private key.
    func deleteIdentity(_ identity: Identity) {
        KeychainStore.delete(for: identity.publicKeyHex)
        modelContext.delete(identity)
        try? modelContext.save()
    }

    // MARK: - Query

    /// Get all identities ordered by creation date.
    func listIdentities() throws -> [Identity] {
        let descriptor = FetchDescriptor<Identity>(sortBy: [SortDescriptor(\.createdAt)])
        return try modelContext.fetch(descriptor)
    }

    /// Get the next available passkey index.
    func nextPasskeyIndex() throws -> Int {
        let identities = try listIdentities()
        let maxIndex = identities.filter(\.isPasskeyDerived).map(\.index).max() ?? -1
        return maxIndex + 1
    }

    /// Reconstruct a keypair from Keychain for signing.
    func getKeypair(for publicKeyHex: String) throws -> NostrPasskeyKeypair {
        guard let privateKeyHex = KeychainStore.load(for: publicKeyHex) else {
            throw IdentityError.keyNotFound
        }
        return try NostrPasskeyKeypair.fromHex(privateKeyHex)
    }

    // MARK: - Private

    private func saveIdentity(
        keypair: NostrPasskeyKeypair,
        label: String,
        index: Int,
        isPasskeyDerived: Bool
    ) throws -> Identity {
        // Store raw hex private key in Keychain (SecretKey.parse expects hex, not nsec)
        let privateKeyHex = try NostrPasskey.NIP19.nsecDecode(keypair.exportNsec())
        try KeychainStore.save(privateKeyHex: privateKeyHex, for: keypair.publicKeyHex)

        // Store public metadata in SwiftData
        let identity = Identity(
            publicKeyHex: keypair.publicKeyHex,
            npub: keypair.npub,
            label: label,
            index: index,
            isPasskeyDerived: isPasskeyDerived
        )
        modelContext.insert(identity)
        try modelContext.save()
        return identity
    }
}

enum IdentityError: Error, LocalizedError {
    case keyNotFound

    var errorDescription: String? {
        switch self {
        case .keyNotFound: "Private key not found in Keychain."
        }
    }
}
