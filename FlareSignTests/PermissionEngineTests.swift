import Testing
@testable import FlareSign

@Suite("Permission Engine Tests")
struct PermissionEngineTests {

    @Test("get_public_key always allowed")
    func getPublicKeyAllowed() {
        let decision = PermissionEngine.evaluate(method: "get_public_key", kind: nil, permissions: [])
        #expect(decision == .allow)
    }

    @Test("ping always allowed")
    func pingAllowed() {
        let decision = PermissionEngine.evaluate(method: "ping", kind: nil, permissions: [])
        #expect(decision == .allow)
    }

    @Test("connect always asks")
    func connectAsks() {
        let decision = PermissionEngine.evaluate(method: "connect", kind: nil, permissions: [])
        #expect(decision == .ask)
    }

    @Test("sign_event Kind 0 auto-approved by default")
    func signMetadataAllowed() {
        let decision = PermissionEngine.evaluate(method: "sign_event", kind: 0, permissions: [])
        #expect(decision == .allow)
    }

    @Test("sign_event Kind 3 auto-approved by default")
    func signContactsAllowed() {
        let decision = PermissionEngine.evaluate(method: "sign_event", kind: 3, permissions: [])
        #expect(decision == .allow)
    }

    @Test("sign_event Kind 1 asks by default")
    func signNoteAsks() {
        let decision = PermissionEngine.evaluate(method: "sign_event", kind: 1, permissions: [])
        #expect(decision == .ask)
    }

    @Test("nip44_encrypt asks by default")
    func encryptAsks() {
        let decision = PermissionEngine.evaluate(method: "nip44_encrypt", kind: nil, permissions: [])
        #expect(decision == .ask)
    }

    @Test("Per-app permission overrides default")
    func perAppOverride() {
        let perm = Permission(method: "sign_event", kind: 1, policy: "allow")
        let decision = PermissionEngine.evaluate(method: "sign_event", kind: 1, permissions: [perm])
        #expect(decision == .allow)
    }

    @Test("Per-app deny overrides default allow")
    func perAppDeny() {
        let perm = Permission(method: "sign_event", kind: 0, policy: "deny")
        let decision = PermissionEngine.evaluate(method: "sign_event", kind: 0, permissions: [perm])
        #expect(decision == .deny)
    }

    @Test("Expired permission falls through to default")
    func expiredPermission() {
        let perm = Permission(method: "sign_event", kind: 1, policy: "allow", expiresAt: Date.distantPast)
        let decision = PermissionEngine.evaluate(method: "sign_event", kind: 1, permissions: [perm])
        #expect(decision == .ask)  // expired, falls through to default
    }

    @Test("Method-level permission applies to all kinds")
    func methodLevelPermission() {
        let perm = Permission(method: "sign_event", kind: nil, policy: "allow")
        let decision = PermissionEngine.evaluate(method: "sign_event", kind: 42, permissions: [perm])
        #expect(decision == .allow)
    }

    @Test("Kind-specific permission takes precedence over method-level")
    func kindSpecificPrecedence() {
        let methodLevel = Permission(method: "sign_event", kind: nil, policy: "allow")
        let kindSpecific = Permission(method: "sign_event", kind: 1, policy: "deny")
        let decision = PermissionEngine.evaluate(method: "sign_event", kind: 1, permissions: [methodLevel, kindSpecific])
        #expect(decision == .deny)  // kind-specific wins
    }
}
