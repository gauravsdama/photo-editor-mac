import AppKit
import CoreImage
import Foundation
import Metal
import ImageIO
import UniformTypeIdentifiers

enum ImageExportError: Error, LocalizedError {
    case noImageLoaded
    case couldNotCreateInputImage(String)
    case couldNotRenderImage

    var errorDescription: String? {
        switch self {
        case .noImageLoaded:
            "No image is loaded."
        case let .couldNotCreateInputImage(path):
            "Could not create a Core Image input image from \(path)."
        case .couldNotRenderImage:
            "Could not render the adjusted image."
        }
    }
}

struct ImageExportResult {
    let sourcePath: String
    let outputPath: String
    let width: Int
    let height: Int
    let adjustments: [String: Double]

    var apiRepresentation: JSONObject {
        [
            "sourceName": .string(URL(fileURLWithPath: sourcePath).lastPathComponent),
            "outputName": .string(URL(fileURLWithPath: outputPath).lastPathComponent),
            "width": .number(Double(width)),
            "height": .number(Double(height)),
            "adjustments": .object(adjustments.mapValues(JSONValue.number))
        ]
    }
}

enum ImageExporter {
    /// ImageIO's highest JPEG encoder quality. JPEG is still a lossy delivery format.
    static let maximumJPEGQuality: Double = 1.0
    private static let renderer = ImageRenderEngine()

    static func renderAdjustedPreview(
        sourcePath: String,
        adjustments: AdjustmentState,
        maxDimension: CGFloat
    ) async throws -> NSImage {
        try await renderer.renderAdjustedPreview(
            sourcePath: sourcePath,
            adjustments: adjustments,
            maxDimension: maxDimension
        )
    }

    static func exportAdjustedImage(
        sourcePath: String,
        outputPath: String,
        adjustments: AdjustmentState,
        quality: Double = maximumJPEGQuality,
        format: RenderedExportFormat? = nil
    ) async throws -> ImageExportResult {
        try await renderer.exportAdjustedImage(
            sourcePath: sourcePath,
            outputPath: outputPath,
            adjustments: adjustments,
            quality: quality,
            format: format
        )
    }
}

private actor ImageRenderEngine {
    private let context: CIContext
    private let outputColorSpace: CGColorSpace

    init() {
        let options: [CIContextOption: Any] = [
            .workingColorSpace: CGColorSpace(name: CGColorSpace.extendedLinearDisplayP3)!,
            .workingFormat: CIFormat.RGBAf.rawValue
        ]
        context = MTLCreateSystemDefaultDevice().map { CIContext(mtlDevice: $0, options: options) } ?? CIContext(options: options)
        outputColorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    }

    func renderAdjustedPreview(
        sourcePath: String,
        adjustments: AdjustmentState,
        maxDimension: CGFloat
    ) throws -> NSImage {
        try Task.checkCancellation()
        var image = try PhotoSource.image(at: URL(fileURLWithPath: sourcePath), maximumDimension: maxDimension)
        let originalExtent = image.extent
        image = ImageFilterGraph.apply(adjustments: adjustments, to: image, originalExtent: originalExtent)

        try Task.checkCancellation()
        guard let cgImage = context.createCGImage(image, from: image.extent, format: .RGBAh,
            colorSpace: CGColorSpace(name: CGColorSpace.extendedLinearDisplayP3)!) else {
            throw ImageExportError.couldNotRenderImage
        }
        try Task.checkCancellation()
        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }

    func exportAdjustedImage(
        sourcePath: String,
        outputPath: String,
        adjustments: AdjustmentState,
        quality: Double,
        format: RenderedExportFormat?
    ) throws -> ImageExportResult {
        try Task.checkCancellation()
        let sourceURL = URL(fileURLWithPath: sourcePath)
        let outputURL = URL(fileURLWithPath: outputPath)
        guard sourceURL.resolvingSymlinksInPath().standardizedFileURL != outputURL.resolvingSymlinksInPath().standardizedFileURL else {
            throw CocoaError(.fileWriteFileExists, userInfo: [NSFilePathErrorKey: outputPath])
        }
        let exportFormat = try format ?? RenderedExportFormat.inferred(from: outputURL)
        let allowedExtensions = exportFormat == .jpeg ? ["jpg", "jpeg"] : ["tif", "tiff"]
        guard allowedExtensions.contains(outputURL.pathExtension.lowercased()) else {
            throw PhotoWorkflowError("The filename extension does not match the export format.")
        }
        var image = try PhotoSource.image(at: sourceURL)
        let originalExtent = image.extent
        image = ImageFilterGraph.apply(adjustments: adjustments, to: image, originalExtent: originalExtent)

        let fileManager = FileManager.default
        let outputDirectory = outputURL.deletingLastPathComponent()
        var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: outputURL.path, isDirectory: &isDirectory), isDirectory.boolValue {
            throw CocoaError(.fileWriteInvalidFileName, userInfo: [NSFilePathErrorKey: outputPath])
        }
        try fileManager.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        let temporaryURL = outputDirectory.appendingPathComponent(
            ".\(outputURL.lastPathComponent).\(UUID().uuidString).tmp"
        )
        defer { try? fileManager.removeItem(at: temporaryURL) }

        try Task.checkCancellation()
        let colorSpace: CGColorSpace
        if exportFormat == .tiffFloat32 {
            colorSpace = CGColorSpace(name: CGColorSpace.extendedLinearDisplayP3)!
        } else if exportFormat == .tiff16 {
            colorSpace = image.colorSpace.flatMap { $0.model == .rgb && !CGColorSpaceUsesExtendedRange($0) ? $0 : nil }
                ?? CGColorSpace(name: CGColorSpace.displayP3)!
        } else { colorSpace = outputColorSpace }
        let pixelFormat: CIFormat = exportFormat == .tiffFloat32 ? .RGBAf : (exportFormat == .tiff16 ? .RGBA16 : .RGBA8)
        guard let rendered = context.createCGImage(image, from: image.extent, format: pixelFormat, colorSpace: colorSpace, deferred: true),
              let destination = CGImageDestinationCreateWithURL(temporaryURL as CFURL, exportFormat.contentType.identifier as CFString, 1, nil) else {
            throw ImageExportError.couldNotRenderImage
        }
        var properties = PhotoSource.metadata(at: sourceURL, width: rendered.width, height: rendered.height)
        if exportFormat == .jpeg {
            properties[kCGImageDestinationLossyCompressionQuality as String] = quality.clamped(to: 0.1...1.0)
        } else {
            var tiff = properties[kCGImagePropertyTIFFDictionary as String] as? [String: Any] ?? [:]
            tiff[kCGImagePropertyTIFFCompression as String] = 1 // Uncompressed: no lossy encoder.
            properties[kCGImagePropertyTIFFDictionary as String] = tiff
        }
        CGImageDestinationAddImage(destination, rendered, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw ImageExportError.couldNotRenderImage }
        try Task.checkCancellation()

        if fileManager.fileExists(atPath: outputURL.path) {
            _ = try fileManager.replaceItemAt(outputURL, withItemAt: temporaryURL)
        } else {
            try fileManager.moveItem(at: temporaryURL, to: outputURL)
        }

        return ImageExportResult(
            sourcePath: sourcePath,
            outputPath: outputPath,
            width: Int(originalExtent.width),
            height: Int(originalExtent.height),
            adjustments: adjustments.apiRepresentation
        )
    }

}

enum ImageFilterGraph {
    static func apply(adjustments: AdjustmentState, to inputImage: CIImage, originalExtent: CGRect) -> CIImage {
        var image = inputImage

        let exposure = adjustments.value(for: .exposure)
        if abs(exposure) > 0.001 {
            let filter = CIFilter(name: "CIExposureAdjust")
            filter?.setValue(image, forKey: kCIInputImageKey)
            filter?.setValue(exposure, forKey: kCIInputEVKey)
            image = filter?.outputImage ?? image
        }

        let colorControls = CIFilter(name: "CIColorControls")
        colorControls?.setValue(image, forKey: kCIInputImageKey)
        colorControls?.setValue(adjustments.value(for: .brightness), forKey: kCIInputBrightnessKey)
        colorControls?.setValue(adjustments.value(for: .saturation), forKey: kCIInputSaturationKey)
        colorControls?.setValue((1.0 + adjustments.value(for: .contrast)).clamped(to: 0.0...2.0), forKey: kCIInputContrastKey)
        image = colorControls?.outputImage ?? image

        let highlights = adjustments.value(for: .highlights)
        let shadows = adjustments.value(for: .shadows)
        if abs(highlights) > 0.001 || abs(shadows) > 0.001 {
            let filter = CIFilter(name: "CIHighlightShadowAdjust")
            filter?.setValue(image, forKey: kCIInputImageKey)
            filter?.setValue((1.0 - highlights * 0.6).clamped(to: 0.0...1.0), forKey: "inputHighlightAmount")
            filter?.setValue(shadows, forKey: "inputShadowAmount")
            image = filter?.outputImage ?? image
        }

        let gamma = adjustments.value(for: .gamma)
        if abs(gamma - 1.0) > 0.001 {
            let filter = CIFilter(name: "CIGammaAdjust")
            filter?.setValue(image, forKey: kCIInputImageKey)
            filter?.setValue(gamma, forKey: "inputPower")
            image = filter?.outputImage ?? image
        }

        let hue = adjustments.value(for: .hue)
        if abs(hue) > 0.001 {
            let filter = CIFilter(name: "CIHueAdjust")
            filter?.setValue(image, forKey: kCIInputImageKey)
            filter?.setValue(hue * .pi / 180.0, forKey: kCIInputAngleKey)
            image = filter?.outputImage ?? image
        }

        let temperature = adjustments.value(for: .temperature) / 100.0
        let tint = adjustments.value(for: .tint) / 100.0
        let redBalance = adjustments.value(for: .redBalance)
        let greenBalance = adjustments.value(for: .greenBalance)
        let blueBalance = adjustments.value(for: .blueBalance)
        if abs(temperature) > 0.001 ||
            abs(tint) > 0.001 ||
            abs(redBalance) > 0.001 ||
            abs(greenBalance) > 0.001 ||
            abs(blueBalance) > 0.001 {
            let filter = CIFilter(name: "CIColorMatrix")
            filter?.setValue(image, forKey: kCIInputImageKey)
            filter?.setValue(CIVector(x: 1.0 + temperature * 0.07 + tint * 0.02 + redBalance * 0.18, y: 0, z: 0, w: 0), forKey: "inputRVector")
            filter?.setValue(CIVector(x: 0, y: 1.0 + tint * 0.03 + greenBalance * 0.18, z: 0, w: 0), forKey: "inputGVector")
            filter?.setValue(CIVector(x: 0, y: 0, z: 1.0 - temperature * 0.07 + tint * 0.02 + blueBalance * 0.18, w: 0), forKey: "inputBVector")
            filter?.setValue(CIVector(x: 0, y: 0, z: 0, w: 1), forKey: "inputAVector")
            image = filter?.outputImage ?? image
        }

        let blackLevel = adjustments.value(for: .blackLevel)
        let whiteLevel = adjustments.value(for: .whiteLevel)
        if blackLevel > 0.001 || abs(whiteLevel - 1.0) > 0.001 {
            let filter = CIFilter(name: "CIColorClamp")
            filter?.setValue(image, forKey: kCIInputImageKey)
            filter?.setValue(CIVector(x: blackLevel, y: blackLevel, z: blackLevel, w: 0), forKey: "inputMinComponents")
            filter?.setValue(CIVector(x: whiteLevel, y: whiteLevel, z: whiteLevel, w: 1), forKey: "inputMaxComponents")
            image = filter?.outputImage ?? image
        }

        let vibrance = CIFilter(name: "CIVibrance")
        vibrance?.setValue(image, forKey: kCIInputImageKey)
        vibrance?.setValue(adjustments.value(for: .vibrance), forKey: "inputAmount")
        image = vibrance?.outputImage ?? image

        let noiseReduction = adjustments.value(for: .noiseReduction)
        if noiseReduction > 0.001 {
            let filter = CIFilter(name: "CINoiseReduction")
            filter?.setValue(image, forKey: kCIInputImageKey)
            filter?.setValue(noiseReduction * 0.08, forKey: "inputNoiseLevel")
            filter?.setValue(0.4, forKey: "inputSharpness")
            image = filter?.outputImage ?? image
        }

        let clarity = adjustments.value(for: .clarity)
        if clarity > 0.001 {
            let filter = CIFilter(name: "CIUnsharpMask")
            filter?.setValue(image, forKey: kCIInputImageKey)
            filter?.setValue(2.5, forKey: kCIInputRadiusKey)
            filter?.setValue(clarity * 0.55, forKey: kCIInputIntensityKey)
            image = filter?.outputImage ?? image
        }

        let sharpness = adjustments.value(for: .sharpness)
        if sharpness > 0.001 {
            let filter = CIFilter(name: "CISharpenLuminance")
            filter?.setValue(image, forKey: kCIInputImageKey)
            filter?.setValue(sharpness, forKey: "inputSharpness")
            image = filter?.outputImage ?? image
        }

        let sepia = adjustments.value(for: .sepia)
        if sepia > 0.001 {
            let filter = CIFilter(name: "CISepiaTone")
            filter?.setValue(image, forKey: kCIInputImageKey)
            filter?.setValue(sepia, forKey: kCIInputIntensityKey)
            image = filter?.outputImage ?? image
        }

        let monochrome = adjustments.value(for: .monochrome)
        if monochrome > 0.001 {
            let filter = CIFilter(name: "CIColorMonochrome")
            filter?.setValue(image, forKey: kCIInputImageKey)
            filter?.setValue(CIColor(red: 0.75, green: 0.75, blue: 0.75), forKey: kCIInputColorKey)
            filter?.setValue(monochrome, forKey: kCIInputIntensityKey)
            image = filter?.outputImage ?? image
        }

        let vignette = adjustments.value(for: .vignette)
        if vignette > 0.001 {
            let filter = CIFilter(name: "CIVignette")
            filter?.setValue(image, forKey: kCIInputImageKey)
            filter?.setValue(vignette, forKey: kCIInputIntensityKey)
            filter?.setValue(
                adjustments.value(for: .vignetteRadius) * Double(min(originalExtent.width, originalExtent.height)),
                forKey: kCIInputRadiusKey
            )
            image = filter?.outputImage ?? image
        }

        let bloom = adjustments.value(for: .bloom)
        if bloom > 0.001 {
            let filter = CIFilter(name: "CIBloom")
            filter?.setValue(image, forKey: kCIInputImageKey)
            filter?.setValue(adjustments.value(for: .bloomRadius), forKey: kCIInputRadiusKey)
            filter?.setValue(bloom, forKey: kCIInputIntensityKey)
            image = filter?.outputImage?.cropped(to: originalExtent) ?? image
        }

        let blur = adjustments.value(for: .blur)
        if blur > 0.001 {
            let filter = CIFilter(name: "CIGaussianBlur")
            filter?.setValue(image, forKey: kCIInputImageKey)
            filter?.setValue(blur, forKey: kCIInputRadiusKey)
            image = filter?.outputImage?.cropped(to: originalExtent) ?? image
        }

        return image.cropped(to: originalExtent)
    }
}
