import Foundation
import Testing
@testable import PhaseOnePhotoEditor

@Suite("Action API request parser")
struct ActionAPIParserTests {
    @Test("Parses a complete JSON request")
    func parsesCompleteRequest() throws {
        let body = Data(#"{"exposure":0.5}"#.utf8)
        let data = requestData(
            target: "/api/adjustments/set?source=local&source=latest",
            headers: [
                "Content-Type": "application/json; charset=utf-8",
                "Content-Length": String(body.count)
            ],
            body: body
        )

        let request = try ActionAPIParser.parse(data: data)
        #expect(request.method == "POST")
        #expect(request.path == "/api/adjustments/set")
        #expect(request.query["source"] == "latest")
        #expect(request.body["exposure"]?.numberValue == 0.5)
    }

    @Test("Waits for the declared body length")
    func detectsIncompleteBody() throws {
        let completeBody = Data(#"{"value":1}"#.utf8)
        let partialBody = completeBody.dropLast(2)
        let data = requestData(
            headers: [
                "Content-Type": "application/json",
                "Content-Length": String(completeBody.count)
            ],
            body: Data(partialBody)
        )

        let expectedLength = try ActionAPIParser.expectedRequestLength(in: data)
        #expect(expectedLength == data.count + 2)
        #expect(throws: ActionAPIParserError.incompleteRequest) {
            try ActionAPIParser.parse(data: data)
        }
    }

    @Test("Rejects malformed JSON and unsupported content types")
    func rejectsInvalidBodies() {
        let malformed = Data("not-json".utf8)
        let malformedRequest = requestData(
            headers: [
                "Content-Type": "application/json",
                "Content-Length": String(malformed.count)
            ],
            body: malformed
        )
        #expect(throws: ActionAPIParserError.invalidJSONBody) {
            try ActionAPIParser.parse(data: malformedRequest)
        }

        let json = Data(#"{"ok":true}"#.utf8)
        let wrongTypeRequest = requestData(
            headers: [
                "Content-Type": "text/plain",
                "Content-Length": String(json.count)
            ],
            body: json
        )
        #expect(throws: ActionAPIParserError.unsupportedMediaType) {
            try ActionAPIParser.parse(data: wrongTypeRequest)
        }
    }

    @Test("Enforces request size limits before buffering a body")
    func rejectsOversizedRequests() {
        let oversizedBody = requestData(headers: [
            "Content-Type": "application/json",
            "Content-Length": String(ActionAPIParser.maximumBodyBytes + 1)
        ])
        #expect(throws: ActionAPIParserError.bodyTooLarge) {
            try ActionAPIParser.expectedRequestLength(in: oversizedBody)
        }

        let oversizedHeaders = Data(
            ("GET /health HTTP/1.1\r\nX-Fill: "
             + String(repeating: "a", count: ActionAPIParser.maximumHeaderBytes)).utf8
        )
        #expect(throws: ActionAPIParserError.headersTooLarge) {
            try ActionAPIParser.expectedRequestLength(in: oversizedHeaders)
        }
    }

    private func requestData(
        method: String = "POST",
        target: String = "/api/action",
        headers: [String: String] = [:],
        body: Data = Data()
    ) -> Data {
        let headerLines = headers
            .sorted { $0.key < $1.key }
            .map { "\($0.key): \($0.value)" }
        let head = (["\(method) \(target) HTTP/1.1"] + headerLines + ["", ""])
            .joined(separator: "\r\n")
        var data = Data(head.utf8)
        data.append(body)
        return data
    }
}
