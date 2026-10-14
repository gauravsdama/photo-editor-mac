import AppKit
import CoreImage
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import PhaseOnePhotoEditor

@Suite("Original photo and saved edits")
struct RAWWorkflowTests {
    @Test("TIFF exports retain dimensions, precision, profile and capture metadata")
    func tiffPrecisionAndMetadata() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = directory.appendingPathComponent("original.tiff")
        try fixture(to: source)
        let original = try Data(contentsOf: source)
        for format in [RenderedExportFormat.tiff16, .tiffFloat32] {
            let output = directory.appendingPathComponent("\(format.rawValue).tiff")
            _ = try await ImageExporter.exportAdjustedImage(sourcePath: source.path, outputPath: output.path,
                adjustments: AdjustmentState(), quality: 1, format: format)
            let imageSource = try #require(CGImageSourceCreateWithURL(output as CFURL, nil))
            let image = try #require(CGImageSourceCreateImageAtIndex(imageSource, 0, nil))
            let properties = try #require(CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any])
            #expect(image.width == 64 && image.height == 48)
            #expect(image.bitsPerComponent == (format == .tiff16 ? 16 : 32))
            #expect(image.bitmapInfo.contains(.floatComponents) == (format == .tiffFloat32))
            #expect(image.colorSpace?.model == .rgb)
            #expect(image.colorSpace?.copyICCData() != nil)
            #expect(image.colorSpace?.name != CGColorSpace.sRGB)
            let tiff = try #require(properties[kCGImagePropertyTIFFDictionary as String] as? [String: Any])
            #expect(tiff[kCGImagePropertyTIFFArtist as String] as? String == "Fixture artist")
            #expect((tiff[kCGImagePropertyTIFFCompression as String] as? NSNumber)?.intValue == 1)
            let exif = try #require(properties[kCGImagePropertyExifDictionary as String] as? [String: Any])
            #expect(exif[kCGImagePropertyExifDateTimeOriginal as String] as? String == "2026:10:07 12:00:00")
            let gps = try #require(properties[kCGImagePropertyGPSDictionary as String] as? [String: Any])
            #expect((gps[kCGImagePropertyGPSLatitude as String] as? NSNumber)?.doubleValue == 30)
            if format == .tiffFloat32 {
                let result = CIImage(cgImage: image)
                var pixel = [Float](repeating: 0, count: 4)
                CIContext().render(result, toBitmap: &pixel, rowBytes: 16,
                    bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBAf,
                    colorSpace: CGColorSpace(name: CGColorSpace.extendedLinearDisplayP3))
                #expect(pixel[0] > 1.1, "Floating-point TIFF clipped extended-range highlights")
            }
        }
        #expect(try Data(contentsOf: source) == original)
    }

    @Test("Projects and XMP round-trip edits and detect a changed original")
    func projectAndXMPRoundTrip() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = directory.appendingPathComponent("original.tiff")
        try fixture(to: source)
        for suffix in ["photoedit", "xmp"] {
            let document = directory.appendingPathComponent("original.tiff.\(suffix)")
            try PhotoProjectStore.save(source: source, document: document, adjustments: ["exposure": 0.8], format: .tiff16)
            let project = try PhotoProjectStore.load(document)
            #expect(project.sourceReference == source.lastPathComponent)
            #expect(project.adjustments["exposure"] == 0.8)
            #expect(project.exportFormat == .tiff16)
            #expect(project.sourceURL(relativeTo: document) == source)
        }
        let project = directory.appendingPathComponent("original.tiff.photoedit")
        try Data("changed".utf8).write(to: source)
        #expect(throws: PhotoWorkflowError.self) { try PhotoProjectStore.load(project) }
    }

    @Test("Updating XMP preserves other applications' metadata")
    func preservesForeignXMP() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = directory.appendingPathComponent("original.tiff")
        try fixture(to: source)
        let sidecar = source.appendingPathExtension("xmp")
        let xml = "<x:xmpmeta xmlns:x=\"adobe:ns:meta/\"><rdf:RDF xmlns:rdf=\"http://www.w3.org/1999/02/22-rdf-syntax-ns#\"><rdf:Description xmlns:dc=\"http://purl.org/dc/elements/1.1/\"><dc:title>Keep this title</dc:title></rdf:Description></rdf:RDF></x:xmpmeta>"
        try Data(xml.utf8).write(to: sidecar)
        try PhotoProjectStore.save(source: source, document: sidecar, adjustments: ["exposure": 1], format: .tiffFloat32)
        try PhotoProjectStore.save(source: source, document: sidecar, adjustments: ["exposure": 2], format: .tiffFloat32)
        #expect(try String(contentsOf: sidecar, encoding: .utf8).contains("Keep this title"))
        #expect(try PhotoProjectStore.load(sidecar).adjustments["exposure"] == 2)
    }

    @Test("Save edits and reopen restore the original, adjustments and output settings")
    @MainActor
    func modelRoundTrip() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = directory.appendingPathComponent("original.tiff")
        try fixture(to: source)
        let original = try Data(contentsOf: source)
        let model = AppModel()
        #expect(await model.loadImage(from: source))
        model.setAdjustmentValue(0.75, for: .exposure)
        model.exportFormat = .tiff16
        #expect(model.hasUnsavedEdits)
        let sidecar = source.appendingPathExtension("xmp")
        try await model.saveEdits(to: sidecar)
        #expect(!model.hasUnsavedEdits)
        model.clearWorkspace()
        #expect(await model.loadImage(from: source))
        #expect(model.adjustments.value(for: .exposure) == 0.75)
        #expect(model.exportFormat == .tiff16)
        #expect(!model.hasUnsavedEdits)
        model.setAdjustmentValue(1, for: .exposure)
        #expect(model.hasUnsavedEdits)
        #expect(await model.openEdits(from: sidecar))
        #expect(model.adjustments.value(for: .exposure) == 0.75)
        #expect(try Data(contentsOf: source) == original)
        model.clearWorkspace()
    }

    @Test("A file named RAW cannot pass validation using raster pixels")
    func invalidRAWIsRejected() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let fake = directory.appendingPathComponent("fake.nef")
        try fixture(to: fake)
        #expect(throws: PhotoWorkflowError.self) { try PhotoSource.image(at: fake) }
        #expect(ImageSourceLoader.loadPreviewSynchronously(from: fake, maxDimension: 200) == nil)
    }

    @Test("Invalid recipes and source-overwriting edit documents are rejected")
    func rejectsInvalidRecipesAndOverwrite() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = directory.appendingPathComponent("original.tiff")
        try fixture(to: source)
        let original = try Data(contentsOf: source)
        #expect(throws: PhotoWorkflowError.self) {
            try PhotoProjectStore.save(source: source, document: source, adjustments: [:], format: .tiff16)
        }
        #expect(throws: PhotoWorkflowError.self) {
            try PhotoProjectStore.save(source: source, document: source.appendingPathExtension("photoedit"),
                adjustments: ["exposure": 99], format: .tiff16)
        }
        let unsupported = PhotoProject(version: 2, sourceReference: source.lastPathComponent,
            sourceSHA256: String(repeating: "0", count: 64), adjustments: [:], exportFormat: .tiff16)
        #expect(throws: PhotoWorkflowError.self) { try unsupported.validate() }
        #expect(try Data(contentsOf: source) == original)
    }

    @Test("A real camera RAW decodes sensor data and exports a full-resolution TIFF",
          .enabled(if: ProcessInfo.processInfo.environment["PHOTO_EDITOR_RAW_FIXTURE"] != nil))
    func realRAWFixture() async throws {
        guard let path = ProcessInfo.processInfo.environment["PHOTO_EDITOR_RAW_FIXTURE"] else { return }
        let source = URL(fileURLWithPath: path)
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        #expect(PhotoSource.isRAW(source))
        let hash = try PhotoProjectStore.fingerprint(source)
        let native = try PhotoSource.image(at: source)
        let preview = try #require(ImageSourceLoader.loadPreviewSynchronously(from: source, maxDimension: 600))
        #expect(max(preview.image.width, preview.image.height) <= 600)
        #expect(preview.orientedPixelSize == native.extent.size)

        let neutralPreview = try await ImageExporter.renderAdjustedPreview(
            sourcePath: source.path,
            adjustments: AdjustmentState(),
            maxDimension: 600
        )
        let output = directory.appendingPathComponent("rendered.tiff")
        var adjustments = AdjustmentState()
        adjustments.setValue(0.25, for: .exposure)
        adjustments.setValue(0.15, for: .vibrance)
        let adjustedPreview = try await ImageExporter.renderAdjustedPreview(
            sourcePath: source.path,
            adjustments: adjustments,
            maxDimension: 600
        )
        let neutralData = try #require(neutralPreview.dataProvider?.data) as Data
        let adjustedData = try #require(adjustedPreview.dataProvider?.data) as Data
        #expect(neutralData != adjustedData)

        let result = try await ImageExporter.exportAdjustedImage(sourcePath: source.path, outputPath: output.path, adjustments: adjustments, quality: 1, format: .tiffFloat32)
        #expect(result.width == Int(native.extent.width))
        #expect(result.height == Int(native.extent.height))
        let renderedSource = try #require(CGImageSourceCreateWithURL(output as CFURL, nil))
        let rendered = try #require(CGImageSourceCreateImageAtIndex(renderedSource, 0, nil))
        let renderedProperties = try #require(
            CGImageSourceCopyPropertiesAtIndex(renderedSource, 0, nil) as? [String: Any]
        )
        #expect(rendered.width == result.width)
        #expect(rendered.height == result.height)
        #expect(rendered.bitsPerComponent == 32)
        #expect(rendered.bitmapInfo.contains(.floatComponents))
        #expect(rendered.colorSpace?.copyICCData() != nil)
        #expect((renderedProperties[kCGImagePropertyOrientation as String] as? NSNumber)?.intValue == 1)

        let project = directory.appendingPathComponent("edits.photoedit")
        try PhotoProjectStore.save(
            source: source,
            document: project,
            adjustments: adjustments.apiRepresentation,
            format: .tiffFloat32
        )
        let restored = try PhotoProjectStore.load(project)
        #expect(restored.adjustments == adjustments.apiRepresentation)

        let corrupt = directory.appendingPathComponent("corrupt.\(source.pathExtension)")
        let handle = try FileHandle(forReadingFrom: source)
        let prefix = try handle.read(upToCount: 64 * 1_024) ?? Data()
        try handle.close()
        try prefix.write(to: corrupt, options: .atomic)
        #expect(throws: PhotoWorkflowError.self) { try PhotoSource.image(at: corrupt) }

        let temporaryOutputs = try FileManager.default.contentsOfDirectory(atPath: directory.path)
            .filter { $0.hasPrefix(".rendered.tiff.") && $0.hasSuffix(".tmp") }
        #expect(temporaryOutputs.isEmpty)
        #expect(try PhotoProjectStore.fingerprint(source) == hash)
    }

    private func temporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func fixture(to url: URL) throws {
        let space = CGColorSpace(name: CGColorSpace.extendedLinearDisplayP3)!
        let image = CIImage(color: CIColor(red: 1.5, green: 0.3, blue: 0.2, colorSpace: space)!)
            .cropped(to: CGRect(x: 0, y: 0, width: 64, height: 48))
        let rendered = try #require(CIContext().createCGImage(image, from: image.extent, format: .RGBAf, colorSpace: space))
        let destination = try #require(CGImageDestinationCreateWithURL(url as CFURL, UTType.tiff.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, rendered, [
            kCGImagePropertyTIFFDictionary: [kCGImagePropertyTIFFArtist: "Fixture artist"],
            kCGImagePropertyExifDictionary: [kCGImagePropertyExifDateTimeOriginal: "2026:10:07 12:00:00"],
            kCGImagePropertyGPSDictionary: [kCGImagePropertyGPSLatitude: 30, kCGImagePropertyGPSLatitudeRef: "N"]
        ] as CFDictionary)
        #expect(CGImageDestinationFinalize(destination))
    }
}
