import CryptoKit
import Foundation

struct PhotoProject: Codable, Sendable {
    var version = 1
    var pipelineVersion = 1
    let sourceReference: String
    let sourceSHA256: String
    let adjustments: [String: Double]
    let exportFormat: RenderedExportFormat

    func validate() throws {
        guard version == 1, pipelineVersion == 1 else {
            throw PhotoWorkflowError("This edit document uses an unsupported version.")
        }
        guard !sourceReference.isEmpty, sourceSHA256.count == 64 else {
            throw PhotoWorkflowError("The edit document has an invalid original-image reference.")
        }
        for (key, value) in adjustments {
            guard let control = AdjustmentControl(rawValue: key), value.isFinite, control.range.contains(value) else {
                throw PhotoWorkflowError("The edit document contains an invalid adjustment.")
            }
        }
    }

    func sourceURL(relativeTo document: URL) -> URL {
        if sourceReference.hasPrefix("/") { return URL(fileURLWithPath: sourceReference) }
        return document.deletingLastPathComponent().appendingPathComponent(sourceReference).standardizedFileURL
    }
}

enum PhotoProjectStore {
    static let namespace = "https://gauravdama.dev/photo-editor/1.0/"
    static let maximumDocumentBytes = 4 * 1_024 * 1_024

    static func fingerprint(_ url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hash = SHA256()
        while let data = try handle.read(upToCount: 1_024 * 1_024), !data.isEmpty {
            try Task.checkCancellation()
            hash.update(data: data)
        }
        return hash.finalize().map { String(format: "%02x", $0) }.joined()
    }

    static func save(source: URL, document: URL, adjustments: [String: Double], format: RenderedExportFormat) throws {
        let source = source.resolvingSymlinksInPath().standardizedFileURL
        let target = document.resolvingSymlinksInPath().standardizedFileURL
        guard source != target else { throw PhotoWorkflowError("Edits must be saved separately from the original photograph.") }
        guard ["photoedit", "xmp"].contains(document.pathExtension.lowercased()) else {
            throw PhotoWorkflowError("Choose a .photoedit project or an .xmp sidecar.")
        }
        let reference = source.deletingLastPathComponent() == target.deletingLastPathComponent()
            ? source.lastPathComponent : source.path
        let project = PhotoProject(sourceReference: reference, sourceSHA256: try fingerprint(source), adjustments: adjustments, exportFormat: format)
        try project.validate()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(project)
        if document.pathExtension.lowercased() == "xmp" {
            let xml: XMLDocument
            if FileManager.default.fileExists(atPath: document.path) {
                xml = try XMLDocument(data: boundedData(document), options: [.nodePreserveAll, .nodeLoadExternalEntitiesNever])
            } else {
                xml = try XMLDocument(xmlString: "<x:xmpmeta xmlns:x=\"adobe:ns:meta/\"><rdf:RDF xmlns:rdf=\"http://www.w3.org/1999/02/22-rdf-syntax-ns#\"/></x:xmpmeta>", options: [])
            }
            guard let rdf = try xml.nodes(forXPath: "//*[local-name()='RDF']").first(where: { $0.uri == "http://www.w3.org/1999/02/22-rdf-syntax-ns#" }) as? XMLElement else {
                throw PhotoWorkflowError("The sidecar does not contain a valid XMP RDF document.")
            }
            for node in try xml.nodes(forXPath: "//*[local-name()='Project']") where node.uri == namespace { node.detach() }
            let description = XMLElement(name: "rdf:Description", uri: "http://www.w3.org/1999/02/22-rdf-syntax-ns#")
            description.addNamespace(XMLNode.namespace(withName: "pe", stringValue: namespace) as! XMLNode)
            let payload = XMLElement(name: "pe:Project", uri: namespace)
            payload.stringValue = data.base64EncodedString()
            description.addChild(payload)
            rdf.addChild(description)
            try xml.xmlData(options: .nodePrettyPrint).write(to: document, options: .atomic)
        } else {
            try data.write(to: document, options: .atomic)
        }
    }

    static func load(_ document: URL) throws -> PhotoProject {
        var data = try boundedData(document)
        if document.pathExtension.lowercased() == "xmp" {
            let xml = try XMLDocument(data: data, options: [.nodeLoadExternalEntitiesNever])
            let nodes = try xml.nodes(forXPath: "//*[local-name()='Project']").filter { $0.uri == namespace }
            guard nodes.count == 1, let payload = nodes.first?.stringValue,
                  let decoded = Data(base64Encoded: payload) else {
                throw PhotoWorkflowError("This XMP sidecar does not contain Photo Editor adjustments.")
            }
            data = decoded
        }
        let project = try JSONDecoder().decode(PhotoProject.self, from: data)
        try project.validate()
        let source = project.sourceURL(relativeTo: document)
        guard try fingerprint(source) == project.sourceSHA256 else {
            throw PhotoWorkflowError("The original photograph has changed since these edits were saved.")
        }
        return project
    }

    private static func boundedData(_ url: URL) throws -> Data {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let data = try handle.read(upToCount: maximumDocumentBytes + 1) ?? Data()
        guard data.count <= maximumDocumentBytes else { throw PhotoWorkflowError("The edit document is too large.") }
        return data
    }
}
