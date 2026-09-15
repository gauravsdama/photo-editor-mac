import AppKit
import CoreImage
import Foundation
import Testing
@testable import PhaseOnePhotoEditor

@Suite("Image exporter integration")
struct ImageExporterTests {
    @Test("Corrupt image input fails without changing the file")
    func corruptInputFails() async throws {
        let workspace = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: workspace) }
        let source = workspace.appendingPathComponent("corrupt.png")
        let original = Data("not an image".utf8)
        try original.write(to: source)

        var didRejectInput = false
        do {
            _ = try await ImageExporter.renderAdjustedPreview(
                sourcePath: source.path,
                adjustments: AdjustmentState(),
                maxDimension: 1_200
            )
        } catch ImageExportError.couldNotCreateInputImage {
            didRejectInput = true
        }

        #expect(didRejectInput)
        #expect(try Data(contentsOf: source) == original)
    }

    @Test("Large source previews are bounded and exports remain full resolution")
    func largeImagePreviewAndExport() async throws {
        let workspace = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: workspace) }
        let source = workspace.appendingPathComponent("large-source.jpg")
        let output = workspace.appendingPathComponent("large-export.jpg")
        try writeJPEG(width: 6_000, height: 4_000, to: source)
        let sourceBefore = try Data(contentsOf: source)

        var adjustments = AdjustmentState()
        adjustments.setValue(0.7, for: .exposure)
        adjustments.setValue(0.2, for: .contrast)

        for _ in 0..<4 {
            let preview = try await ImageExporter.renderAdjustedPreview(
                sourcePath: source.path,
                adjustments: adjustments,
                maxDimension: 1_200
            )
            #expect(max(preview.size.width, preview.size.height) <= 1_200)
        }

        let result = try await ImageExporter.exportAdjustedImage(
            sourcePath: source.path,
            outputPath: output.path,
            adjustments: adjustments,
            quality: 0.9
        )

        #expect(result.width == 6_000)
        #expect(result.height == 4_000)
        #expect(FileManager.default.fileExists(atPath: output.path))
        #expect(try Data(contentsOf: source) == sourceBefore)
    }

    @Test("Export reports a write failure")
    func exportWriteFailure() async throws {
        let workspace = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: workspace) }
        let source = workspace.appendingPathComponent("source.jpg")
        let outputDirectory = workspace.appendingPathComponent("output-target")
        try writeJPEG(width: 64, height: 64, to: source)
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

        var didFail = false
        do {
            _ = try await ImageExporter.exportAdjustedImage(
                sourcePath: source.path,
                outputPath: outputDirectory.path,
                adjustments: AdjustmentState(),
                quality: 0.9
            )
        } catch {
            didFail = true
        }

        #expect(didFail)
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("photo-editor-tests-")
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func writeJPEG(width: Int, height: Int, to url: URL) throws {
        let image = CIImage(color: CIColor(red: 0.24, green: 0.48, blue: 0.72))
            .cropped(to: CGRect(x: 0, y: 0, width: width, height: height))
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
        let context = CIContext(options: [.useSoftwareRenderer: true])
        guard let data = context.jpegRepresentation(
            of: image,
            colorSpace: colorSpace,
            options: [:]
        ) else {
            throw ImageExportError.couldNotEncodeJPEG
        }
        try data.write(to: url, options: .atomic)
    }
}
