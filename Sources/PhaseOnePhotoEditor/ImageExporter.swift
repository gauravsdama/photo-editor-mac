import AppKit
import CoreImage
import Foundation
import Metal

enum ImageExportError: Error, LocalizedError {
    case noImageLoaded
    case couldNotCreateInputImage(String)
    case couldNotRenderImage
    case couldNotEncodeJPEG

    var errorDescription: String? {
        switch self {
        case .noImageLoaded:
            "No image is loaded."
        case let .couldNotCreateInputImage(path):
            "Could not create a Core Image input image from \(path)."
        case .couldNotRenderImage:
            "Could not render the adjusted image."
        case .couldNotEncodeJPEG:
            "Could not encode the adjusted image as JPEG."
        }
    }
}

struct ImageExportResult {
    let sourcePath: String
    let outputPath: String
    let width: Int
    let height: Int
    let adjustments: [String: Double]

    var apiRepresentation: [String: Any] {
        [
            "sourcePath": sourcePath,
            "outputPath": outputPath,
            "width": width,
            "height": height,
            "adjustments": adjustments
        ]
    }
}

enum ImageExporter {
    static func renderAdjustedPreview(
        sourcePath: String,
        adjustments: AdjustmentState,
        maxDimension: CGFloat
    ) async throws -> NSImage {
        try await Task.detached(priority: .userInitiated) {
            guard var image = CIImage(
                contentsOf: URL(fileURLWithPath: sourcePath),
                options: [.applyOrientationProperty: true]
            ) else {
                throw ImageExportError.couldNotCreateInputImage(sourcePath)
            }

            let originalExtent = image.extent
            image = apply(adjustments: adjustments, to: image, originalExtent: originalExtent)
            let longestEdge = max(originalExtent.width, originalExtent.height)
            let scale = longestEdge > maxDimension ? maxDimension / longestEdge : 1
            if scale < 1 {
                let filter = CIFilter(name: "CILanczosScaleTransform")
                filter?.setValue(image, forKey: kCIInputImageKey)
                filter?.setValue(scale, forKey: kCIInputScaleKey)
                filter?.setValue(1.0, forKey: kCIInputAspectRatioKey)
                image = filter?.outputImage ?? image
            }

            let context = MTLCreateSystemDefaultDevice().map(CIContext.init(mtlDevice:)) ?? CIContext()
            guard let cgImage = context.createCGImage(image, from: image.extent) else {
                throw ImageExportError.couldNotRenderImage
            }
            return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        }.value
    }

    static func exportAdjustedImage(
        sourcePath: String,
        outputPath: String,
        adjustments: AdjustmentState,
        quality: Double
    ) async throws -> ImageExportResult {
        try await Task.detached(priority: .userInitiated) {
            let sourceURL = URL(fileURLWithPath: sourcePath)
            let outputURL = URL(fileURLWithPath: outputPath)

            guard var image = CIImage(contentsOf: sourceURL, options: [.applyOrientationProperty: true]) else {
                throw ImageExportError.couldNotCreateInputImage(sourcePath)
            }
            let originalExtent = image.extent

            image = apply(adjustments: adjustments, to: image, originalExtent: originalExtent)

            let context: CIContext
            if let device = MTLCreateSystemDefaultDevice() {
                context = CIContext(mtlDevice: device)
            } else {
                context = CIContext()
            }

            guard let cgImage = context.createCGImage(image, from: originalExtent) else {
                throw ImageExportError.couldNotRenderImage
            }

            let bitmap = NSBitmapImageRep(cgImage: cgImage)
            guard let data = bitmap.representation(
                using: .jpeg,
                properties: [.compressionFactor: quality.clamped(to: 0.1...1.0)]
            ) else {
                throw ImageExportError.couldNotEncodeJPEG
            }

            try FileManager.default.createDirectory(
                at: outputURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: outputURL, options: [.atomic])

            return ImageExportResult(
                sourcePath: sourcePath,
                outputPath: outputPath,
                width: cgImage.width,
                height: cgImage.height,
                adjustments: adjustments.apiRepresentation
            )
        }.value
    }

    private static func apply(adjustments: AdjustmentState, to inputImage: CIImage, originalExtent: CGRect) -> CIImage {
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
