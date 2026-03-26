import Testing
import Foundation
@testable import FlareSign

@Suite("NIP-46 Message Tests")
struct NIP46MessageTests {

    @Test("Encode NIP46Request to JSON")
    func encodeRequest() throws {
        let request = NIP46Request(id: "abc123", method: "sign_event", params: ["{\"kind\":1}"])
        let json = try JSONEncoder().encode(request)
        let dict = try JSONSerialization.jsonObject(with: json) as? [String: Any]
        #expect(dict?["id"] as? String == "abc123")
        #expect(dict?["method"] as? String == "sign_event")
    }

    @Test("Decode NIP46Request from JSON")
    func decodeRequest() throws {
        let json = """
        {"id":"req_1","method":"get_public_key","params":[]}
        """
        let request = try JSONDecoder().decode(NIP46Request.self, from: Data(json.utf8))
        #expect(request.id == "req_1")
        #expect(request.method == "get_public_key")
        #expect(request.params.isEmpty)
    }

    @Test("Encode NIP46Response success")
    func encodeSuccessResponse() throws {
        let response = NIP46Response.success(id: "req_1", result: "pong")
        let json = try JSONEncoder().encode(response)
        let dict = try JSONSerialization.jsonObject(with: json) as? [String: Any]
        #expect(dict?["id"] as? String == "req_1")
        #expect(dict?["result"] as? String == "pong")
    }

    @Test("Encode NIP46Response error")
    func encodeErrorResponse() throws {
        let response = NIP46Response.error(id: "req_1", message: "denied")
        let json = try JSONEncoder().encode(response)
        let dict = try JSONSerialization.jsonObject(with: json) as? [String: Any]
        #expect(dict?["error"] as? String == "denied")
    }

    @Test("Decode NIP46Response from JSON")
    func decodeResponse() throws {
        let json = """
        {"id":"req_1","result":"ack","error":null}
        """
        let response = try JSONDecoder().decode(NIP46Response.self, from: Data(json.utf8))
        #expect(response.id == "req_1")
        #expect(response.result == "ack")
        #expect(response.error == nil)
    }

    @Test("EventKindLabel known kinds")
    func eventKindLabels() {
        #expect(EventKindLabel.name(for: 0) == "Profile Metadata")
        #expect(EventKindLabel.name(for: 1) == "Short Text Note")
        #expect(EventKindLabel.name(for: 4) == "Encrypted DM (NIP-04)")
        #expect(EventKindLabel.name(for: 10002) == "Relay List")
        #expect(EventKindLabel.name(for: 99999) == "Kind 99999")
    }
}
