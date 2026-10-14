import AppKit
import CoreImage
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import PhaseOnePhotoEditor

@Suite("Image exporter integration")
struct ImageExporterTests {
    private enum FixtureError: Error {
        case couldNotEncodeJPEG
    }
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
            #expect(max(preview.width, preview.height) <= 1_200)
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

    @Test("Export never overwrites the source image")
    func exportPreservesSourcePath() async throws {
        let workspace = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: workspace) }
        let source = workspace.appendingPathComponent("source.jpg")
        try writeJPEG(width: 64, height: 64, to: source)
        let sourceBefore = try Data(contentsOf: source)

        var didFail = false
        do {
            _ = try await ImageExporter.exportAdjustedImage(
                sourcePath: source.path,
                outputPath: source.path,
                adjustments: AdjustmentState(),
                quality: 0.9
            )
        } catch {
            didFail = true
        }

        #expect(didFail)
        #expect(try Data(contentsOf: source) == sourceBefore)
    }

    @Test("Export atomically replaces an existing output file")
    func exportReplacesExistingOutput() async throws {
        let workspace = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: workspace) }
        let source = workspace.appendingPathComponent("source.jpg")
        let output = workspace.appendingPathComponent("output.jpg")
        try writeJPEG(width: 64, height: 32, to: source)
        try Data("old output".utf8).write(to: output)

        let result = try await ImageExporter.exportAdjustedImage(
            sourcePath: source.path,
            outputPath: output.path,
            adjustments: AdjustmentState(),
            quality: 0.9
        )

        #expect(result.width == 64)
        #expect(result.height == 32)
        #expect(try Data(contentsOf: output) != Data("old output".utf8))
        #expect(NSImage(contentsOf: output) != nil)
    }

    @Test("Failed imports clear stale preview state")
    @MainActor
    func failedImportClearsPreview() async throws {
        let workspace = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: workspace) }
        let validSource = workspace.appendingPathComponent("valid.jpg")
        let invalidSource = workspace.appendingPathComponent("invalid.jpg")
        try writeJPEG(width: 64, height: 64, to: validSource)
        try Data("not an image".utf8).write(to: invalidSource)

        let model = AppModel()
        #expect(await model.loadImage(from: validSource))
        #expect(model.adjustedPreviewImage != nil)
        #expect(!(await model.loadImage(from: invalidSource)))
        #expect(model.selectedImage == nil)
        #expect(model.adjustedPreviewImage == nil)
        #expect(!model.isRenderingPreview)
    }

    @Test("Imported display images are bounded while source dimensions remain available")
    @MainActor
    func importedDisplayImageIsBounded() async throws {
        let workspace = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: workspace) }
        let source = workspace.appendingPathComponent("large-import.jpg")
        try writeJPEG(width: 6_000, height: 4_000, to: source)

        let model = AppModel()
        #expect(await model.loadImage(from: source))
        let selectedImage = try #require(model.selectedImage)
        let selectedImageSize = try #require(model.selectedImageSize)
        #expect(max(selectedImage.size.width, selectedImage.size.height) <= AppModel.previewMaximumDimension)
        #expect(selectedImageSize == CGSize(width: 6_000, height: 4_000))
        #expect(model.selectedImagePath == source.path)
    }

    @Test("A slower import cannot replace a newer image")
    @MainActor
    func rapidImportsKeepNewestImage() async throws {
        let workspace = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: workspace) }
        let largeSource = workspace.appendingPathComponent("large.jpg")
        let newestSource = workspace.appendingPathComponent("newest.jpg")
        try writeJPEG(width: 10_000, height: 5_000, to: largeSource)
        try writeJPEG(width: 320, height: 200, to: newestSource)

        let model = AppModel()
        let olderLoad = Task { await model.loadImage(from: largeSource) }
        await Task.yield()
        let newerLoad = Task { await model.loadImage(from: newestSource) }
        _ = await olderLoad.value
        #expect(await newerLoad.value)
        #expect(model.selectedImagePath == newestSource.path)
        #expect(model.selectedImageSize == CGSize(width: 320, height: 200))
    }

    @Test("Import and export apply source orientation consistently")
    @MainActor
    func orientationIsConsistent() async throws {
        let workspace = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: workspace) }
        let source = workspace.appendingPathComponent("oriented.jpg")
        let output = workspace.appendingPathComponent("oriented-export.jpg")
        try writeJPEG(width: 80, height: 40, orientation: .right, to: source)

        let model = AppModel()
        #expect(await model.loadImage(from: source))
        #expect(model.selectedImageSize == CGSize(width: 40, height: 80))
        #expect(model.selectedImage?.size == CGSize(width: 40, height: 80))

        let result = try await model.exportAdjustedImage(to: output, quality: 0.9)
        #expect(result.width == 40)
        #expect(result.height == 80)
    }

    @Test("JPEG quality affects encoding and export uses an RGB profile")
    func exportQualityAndColorSpace() async throws {
        let workspace = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: workspace) }
        let source = workspace.appendingPathComponent("gradient.jpg")
        let lowQuality = workspace.appendingPathComponent("low.jpg")
        let highQuality = workspace.appendingPathComponent("high.jpg")
        try writeGradientJPEG(width: 256, height: 256, to: source)

        _ = try await ImageExporter.exportAdjustedImage(
            sourcePath: source.path,
            outputPath: lowQuality.path,
            adjustments: AdjustmentState(),
            quality: 0.1
        )
        _ = try await ImageExporter.exportAdjustedImage(
            sourcePath: source.path,
            outputPath: highQuality.path,
            adjustments: AdjustmentState()
        )

        let lowSize = try FileManager.default.attributesOfItem(atPath: lowQuality.path)[.size] as? NSNumber
        let highSize = try FileManager.default.attributesOfItem(atPath: highQuality.path)[.size] as? NSNumber
        #expect(try #require(lowSize).intValue < #require(highSize).intValue)
        let imageSource = try #require(CGImageSourceCreateWithURL(highQuality as CFURL, nil))
        let properties = try #require(
            CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any]
        )
        #expect(properties[kCGImagePropertyColorModel] as? String == kCGImagePropertyColorModelRGB as String)
        #expect(properties[kCGImagePropertyProfileName] != nil)
        #expect(properties[kCGImagePropertyPixelWidth] as? Int == 256)
        #expect(properties[kCGImagePropertyPixelHeight] as? Int == 256)

        // Inspect actual encoder output, not just the requested quality property.
        let bytes = [UInt8](try Data(contentsOf: highQuality))
        var offset = 2 // Skip JPEG SOI.
        var samplingFactors: [UInt8] = []
        var quantizationValues: [UInt8] = []
        while offset + 4 <= bytes.count {
            #expect(bytes[offset] == 0xff)
            let marker = bytes[offset + 1]
            if marker == 0xda || marker == 0xd9 { break }
            let length = Int(bytes[offset + 2]) * 256 + Int(bytes[offset + 3])
            let start = offset + 4
            let end = offset + 2 + length
            guard length >= 2, end <= bytes.count else { throw FixtureError.couldNotEncodeJPEG }
            if marker == 0xc0 || marker == 0xc2 {
                let count = Int(bytes[start + 5])
                for component in 0..<count { samplingFactors.append(bytes[start + 7 + component * 3]) }
            }
            if marker == 0xdb {
                var tableOffset = start
                while tableOffset < end {
                    #expect(bytes[tableOffset] >> 4 == 0) // 8-bit quantization table.
                    guard tableOffset + 65 <= end else { throw FixtureError.couldNotEncodeJPEG }
                    quantizationValues.append(contentsOf: bytes[(tableOffset + 1)..<(tableOffset + 65)])
                    tableOffset += 65
                }
            }
            offset = end
        }
        #expect(samplingFactors == [0x11, 0x11, 0x11]) // Full-resolution 4:4:4 color.
        #expect(!quantizationValues.isEmpty)
        #expect(quantizationValues.allSatisfy { $0 == 1 }) // Minimum quantization step.
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
            throw FixtureError.couldNotEncodeJPEG
        }
        try data.write(to: url, options: .atomic)
    }

    private func writeJPEG(
        width: Int,
        height: Int,
        orientation: CGImagePropertyOrientation,
        to url: URL
    ) throws {
        let image = CIImage(color: CIColor(red: 0.24, green: 0.48, blue: 0.72))
            .cropped(to: CGRect(x: 0, y: 0, width: width, height: height))
        let context = CIContext(options: [.useSoftwareRenderer: true])
        guard let cgImage = context.createCGImage(image, from: image.extent),
              let destination = CGImageDestinationCreateWithURL(
                  url as CFURL,
                  UTType.jpeg.identifier as CFString,
                  1,
                  nil
              ) else {
            throw FixtureError.couldNotEncodeJPEG
        }
        CGImageDestinationAddImage(
            destination,
            cgImage,
            [kCGImagePropertyOrientation: orientation.rawValue] as CFDictionary
        )
        guard CGImageDestinationFinalize(destination) else {
            throw FixtureError.couldNotEncodeJPEG
        }
    }

    private func writeGradientJPEG(width: Int, height: Int, to url: URL) throws {
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        for y in 0..<height {
            for x in 0..<width {
                let offset = (y * width + x) * 4
                pixels[offset] = UInt8(x * 255 / max(width - 1, 1))
                pixels[offset + 1] = UInt8(y * 255 / max(height - 1, 1))
                pixels[offset + 2] = UInt8((x + y) * 255 / max(width + height - 2, 1))
                pixels[offset + 3] = 255
            }
        }
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
        let image = CIImage(
            bitmapData: Data(pixels),
            bytesPerRow: width * 4,
            size: CGSize(width: width, height: height),
            format: .RGBA8,
            colorSpace: colorSpace
        )
        let context = CIContext(options: [.useSoftwareRenderer: true])
        guard let data = context.jpegRepresentation(of: image, colorSpace: colorSpace) else {
            throw FixtureError.couldNotEncodeJPEG
        }
        try data.write(to: url, options: .atomic)
    }
}
