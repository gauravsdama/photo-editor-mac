import CoreImage
import ImageIO
import UniformTypeIdentifiers

enum PhotoSource {
    static let rawExtensions: Set<String> = ["dng", "nef", "nrw", "cr2", "cr3", "crw", "arw", "srf", "sr2", "raf", "orf", "rw2", "rwl", "pef", "ptx", "srw", "3fr", "fff", "iiq", "kdc", "dcr", "mos", "mrw", "raw", "x3f"]

    static func isRAW(_ url: URL) -> Bool {
        if rawExtensions.contains(url.pathExtension.lowercased()) { return true }
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let type = CGImageSourceGetType(source) else { return false }
        return UTType(type as String)?.conforms(to: .rawImage) == true
    }

    static func image(at url: URL, maximumDimension: CGFloat? = nil) throws -> CIImage {
        var image: CIImage
        if isRAW(url) {
            guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                  let type = CGImageSourceGetType(source),
                  UTType(type as String)?.conforms(to: .rawImage) == true else {
                throw PhotoWorkflowError("The file does not contain a recognized RAW image.")
            }
            // A thumbnail is not evidence that the sensor data can be decoded.
            guard let filter = CIRAWFilter(imageURL: url), !filter.supportedDecoderVersions.isEmpty else {
                throw PhotoWorkflowError("This RAW file is not supported by the RAW decoder on this Mac.")
            }
            filter.isDraftModeEnabled = false
            filter.isGamutMappingEnabled = false
            filter.extendedDynamicRangeAmount = 2
            if let maximumDimension {
                let size = filter.nativeSize
                filter.scaleFactor = Float(min(1, maximumDimension / max(size.width, size.height)))
            }
            guard let output = filter.outputImage else {
                throw PhotoWorkflowError("The RAW sensor data could not be decoded.")
            }
            image = output
        } else {
            guard let output = CIImage(contentsOf: url, options: [.applyOrientationProperty: true]) else {
                throw ImageExportError.couldNotCreateInputImage(url.path)
            }
            image = output
        }
        guard !image.extent.isEmpty, !image.extent.isInfinite else {
            throw PhotoWorkflowError("The image has invalid dimensions.")
        }
        if let maximumDimension {
            let scale = min(1, maximumDimension / max(image.extent.width, image.extent.height))
            image = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        }
        return image
    }

    static func metadata(at url: URL, width: Int, height: Int) -> [String: Any] {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] else { return [:] }
        var result: [String: Any] = [:]
        // Retain descriptive/capture metadata, including location, but never stale image-layout tags.
        for key in [kCGImagePropertyExifDictionary, kCGImagePropertyExifAuxDictionary,
                    kCGImagePropertyGPSDictionary, kCGImagePropertyIPTCDictionary, kCGImagePropertyTIFFDictionary] {
            if let value = properties[key as String] { result[key as String] = value }
        }
        if var exif = result[kCGImagePropertyExifDictionary as String] as? [String: Any] {
            exif.removeValue(forKey: kCGImagePropertyExifMakerNote as String)
            exif.removeValue(forKey: kCGImagePropertyExifColorSpace as String)
            exif[kCGImagePropertyExifPixelXDimension as String] = width
            exif[kCGImagePropertyExifPixelYDimension as String] = height
            result[kCGImagePropertyExifDictionary as String] = exif
        }
        if var tiff = result[kCGImagePropertyTIFFDictionary as String] as? [String: Any] {
            for key in ["Orientation", "Compression", "PhotometricInterpretation", "BitsPerSample", "SamplesPerPixel", "ImageWidth", "ImageLength"] { tiff.removeValue(forKey: key) }
            result[kCGImagePropertyTIFFDictionary as String] = tiff
        }
        result[kCGImagePropertyOrientation as String] = 1
        return result
    }
}

struct PhotoWorkflowError: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}

enum RenderedExportFormat: String, CaseIterable, Identifiable, Codable, Sendable {
    case tiffFloat32, tiff16, jpeg
    var id: String { rawValue }
    var title: String {
        switch self {
        case .tiffFloat32: "TIFF · 32-bit float · maximum precision"
        case .tiff16: "TIFF · 16-bit · lossless"
        case .jpeg: "JPEG · maximum quality"
        }
    }
    var fileExtension: String { self == .jpeg ? "jpg" : "tiff" }
    var contentType: UTType { self == .jpeg ? .jpeg : .tiff }
    static func inferred(from url: URL) throws -> Self {
        switch url.pathExtension.lowercased() {
        case "tif", "tiff": .tiffFloat32
        case "jpg", "jpeg": .jpeg
        default: throw PhotoWorkflowError("Choose a TIFF or JPEG destination.")
        }
    }
}
