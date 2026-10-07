import Foundation
import Testing
@testable import PhaseOnePhotoEditor

@Suite("Action API typed payloads")
@MainActor
struct ActionAPIHandlerTests {
    @Test("Wrong field types and invalid numeric values are rejected")
    func rejectsInvalidFieldValues() async {
        let model = AppModel()
        let requests: [ActionAPIRequest] = [
            request(path: "/api/image/open", body: ["path": 42]),
            request(path: "/api/controls/visible", body: ["controls": ["exposure", 3]]),
            request(path: "/api/adjustments/set", body: ["exposure": "high"]),
            request(path: "/api/adjustments/set", body: ["exposure": 9]),
            request(path: "/api/adjustments/set", body: ["unknown": 1]),
            request(path: "/api/image/export", body: ["outputPath": "/tmp/test.jpg", "quality": "best"]),
            request(path: "/api/image/export", body: ["outputPath": "/tmp/test.jpg", "quality": 2]),
            request(path: "/api/action", body: ["action": "open_image", "parameters": "invalid"])
        ]

        for request in requests {
            let response = await model.handleActionAPIRequest(request)
            #expect(response.statusCode == 400, "Accepted invalid payload for \(request.path)")
        }
    }

    @Test("Typed JSON response preserves the HTTP payload shape")
    func responseSerialization() throws {
        let response = ActionAPIResponse.json([
            "ok": true,
            "count": 2,
            "name": "Photo Editor",
            "items": ["one", "two"]
        ])
        let data = response.httpData()
        let separator = Data([13, 10, 13, 10])
        let range = try #require(data.range(of: separator))
        let headers = try #require(String(data: data[..<range.lowerBound], encoding: .utf8))
        let body = data[range.upperBound...]
        let object = try #require(
            JSONSerialization.jsonObject(with: Data(body)) as? [String: Any]
        )

        #expect(object["ok"] as? Bool == true)
        #expect(object["count"] as? Int == 2)
        #expect(object["name"] as? String == "Photo Editor")
        #expect(object["items"] as? [String] == ["one", "two"])
        #expect(headers.contains("Access-Control-Allow-Origin: http://127.0.0.1"))
        #expect(headers.contains("Access-Control-Allow-Headers: Content-Type, Authorization"))
    }

    @Test("API representations do not disclose full local paths")
    func redactsLocalPaths() throws {
        let result = ImageExportResult(
            sourcePath: "/private/var/Pictures/source.jpg",
            outputPath: "/tmp/private/export.jpg",
            width: 100,
            height: 80,
            adjustments: [:]
        )
        let encodedResult = try JSONEncoder().encode(JSONValue.object(result.apiRepresentation))
        let resultText = try #require(String(data: encodedResult, encoding: .utf8))
        #expect(!resultText.contains("/private/var/"))
        #expect(!resultText.contains("/tmp/"))
        #expect(resultText.contains("source.jpg"))
        #expect(resultText.contains("export.jpg"))

        let logEntry = CommandLogEntry(title: "Opened image", detail: "/private/var/Pictures/source.jpg")
        #expect(logEntry.apiRepresentation["detail"] == nil)
    }

    private func request(path: String, body: JSONObject) -> ActionAPIRequest {
        ActionAPIRequest(method: "POST", path: path, query: [:], headers: [:], body: body)
    }
}
