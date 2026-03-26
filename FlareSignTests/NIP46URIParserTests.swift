import Testing
@testable import FlareSign

@Suite("NIP-46 URI Parser Tests")
struct NIP46URIParserTests {

    @Test("Parse valid nostrconnect:// URI")
    func parseNostrConnect() {
        let uri = "nostrconnect://abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890?relay=wss://relay.damus.io&secret=mysecret&name=Damus&perms=sign_event:1,nip44_encrypt"
        let params = NIP46URIParser.parseNostrConnect(uri)
        #expect(params != nil)
        #expect(params?.clientPubkey == "abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890")
        #expect(params?.relays == ["wss://relay.damus.io"])
        #expect(params?.secret == "mysecret")
        #expect(params?.name == "Damus")
        #expect(params?.permissions == ["sign_event:1", "nip44_encrypt"])
    }

    @Test("Parse nostrconnect:// with multiple relays")
    func parseMultipleRelays() {
        let uri = "nostrconnect://abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890?relay=wss://relay.damus.io&relay=wss://nos.lol"
        let params = NIP46URIParser.parseNostrConnect(uri)
        #expect(params?.relays.count == 2)
    }

    @Test("Reject nostrconnect:// with invalid pubkey")
    func rejectInvalidPubkey() {
        let uri = "nostrconnect://tooshort?relay=wss://relay.damus.io"
        #expect(NIP46URIParser.parseNostrConnect(uri) == nil)
    }

    @Test("Reject nostrconnect:// with no relay")
    func rejectNoRelay() {
        let uri = "nostrconnect://abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890"
        #expect(NIP46URIParser.parseNostrConnect(uri) == nil)
    }

    @Test("Parse valid bunker:// URI")
    func parseBunker() {
        let uri = "bunker://abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890?relay=wss://relay.damus.io&secret=abc"
        let params = NIP46URIParser.parseBunker(uri)
        #expect(params != nil)
        #expect(params?.signerPubkey == "abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890")
        #expect(params?.relays == ["wss://relay.damus.io"])
        #expect(params?.secret == "abc")
    }

    @Test("Generate bunker:// URI")
    func generateBunker() {
        let uri = NIP46URIParser.generateBunkerURI(
            signerPubkey: "abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890",
            relays: ["wss://relay.damus.io"],
            secret: "test123"
        )
        #expect(uri.hasPrefix("bunker://"))
        #expect(uri.contains("relay="))
        #expect(uri.contains("secret=test123"))
    }

    @Test("Reject non-nostrconnect scheme")
    func rejectWrongScheme() {
        #expect(NIP46URIParser.parseNostrConnect("https://example.com") == nil)
        #expect(NIP46URIParser.parseBunker("nostrconnect://abc") == nil)
    }
}
