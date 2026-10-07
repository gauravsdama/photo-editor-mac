import Testing
@testable import PhaseOnePhotoEditor

@Suite("Action API catalog contract")
@MainActor
struct ActionCatalogTests {
    @Test("Action names and direct routes are unique and routable")
    func descriptorsAreUniqueAndRoutable() async {
        let descriptors = ActionCatalog.descriptors
        #expect(Set(descriptors.map(\.action.rawValue)).count == descriptors.count)
        #expect(Set(descriptors.map { "\($0.method) \($0.path)" }).count == descriptors.count)

        let model = AppModel()
        for descriptor in descriptors {
            let response = await model.handleActionAPIRequest(
                ActionAPIRequest(
                    method: descriptor.method,
                    path: descriptor.path,
                    query: [:],
                    headers: [:],
                    body: [:]
                )
            )
            #expect(response.statusCode != 404, "Descriptor did not route: \(descriptor.action.rawValue)")
        }
    }

    @Test("Generic and direct dispatch share response behavior")
    func genericAndDirectDispatchAreEquivalent() async {
        let model = AppModel()
        let directControls = await model.handleActionAPIRequest(
            request(method: "GET", path: "/api/controls", body: [:])
        )
        let genericControls = await model.handleActionAPIRequest(
            request(method: "POST", path: "/api/action", body: ["action": "list_controls"])
        )
        #expect(directControls == genericControls)

        let directOpen = await model.handleActionAPIRequest(
            request(method: "POST", path: "/api/image/open", body: [:])
        )
        let genericOpen = await model.handleActionAPIRequest(
            request(method: "POST", path: "/api/action", body: ["action": "open_image"])
        )
        #expect(directOpen == genericOpen)
    }

    @Test("Export outputPath is advertised and enforced as required")
    func exportPathContract() async throws {
        let export = try #require(ActionCatalog.descriptor(named: "export_image"))
        let outputPath = try #require(export.parameters.first { $0["name"]?.stringValue == "outputPath" })
        #expect(outputPath["required"] == .bool(true))
        let quality = try #require(export.parameters.first { $0["name"]?.stringValue == "quality" })
        #expect(quality["default"] == .number(ImageExporter.maximumJPEGQuality))

        let response = await AppModel().handleActionAPIRequest(
            request(method: export.method, path: export.path, body: [:])
        )
        #expect(response.statusCode == 400)
    }

    private func request(method: String, path: String, body: JSONObject) -> ActionAPIRequest {
        ActionAPIRequest(method: method, path: path, query: [:], headers: [:], body: body)
    }
}
