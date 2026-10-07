import CoreGraphics
import Foundation
import ImageIO
import CoreImage

struct ImageSourcePreview: Sendable {
    let image: CGImage
    let orientedPixelSize: CGSize
}

enum ImageSourceLoader {
    static func loadPreview(
        from url: URL,
        maxDimension: CGFloat
    ) async -> ImageSourcePreview? {
        await Task.detached(priority: .userInitiated) {
            loadPreviewSynchronously(from: url, maxDimension: maxDimension)
        }.value
    }

    static func loadPreviewSynchronously(
        from url: URL,
        maxDimension: CGFloat
    ) -> ImageSourcePreview? {
        guard maxDimension > 0,
              let source = CGImageSourceCreateWithURL(
                  url as CFURL,
                  [kCGImageSourceShouldCache: false] as CFDictionary
              ),
              CGImageSourceGetCount(source) > 0,
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.doubleValue,
              let height = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.doubleValue,
              width > 0,
              height > 0 else {
            return nil
        }

        let orientationValue = (properties[kCGImagePropertyOrientation] as? NSNumber)?.uint32Value ?? 1
        let swapsDimensions = [5, 6, 7, 8].contains(orientationValue)
        let orientedSize = swapsDimensions
            ? CGSize(width: height, height: width)
            : CGSize(width: width, height: height)
        if PhotoSource.isRAW(url) {
            guard let fullImage = try? PhotoSource.image(at: url),
                  let image = try? PhotoSource.image(at: url, maximumDimension: maxDimension),
                  let cgImage = CIContext().createCGImage(image, from: image.extent, format: .RGBAh,
                    colorSpace: CGColorSpace(name: CGColorSpace.extendedLinearDisplayP3)!) else { return nil }
            return ImageSourcePreview(image: cgImage, orientedPixelSize: fullImage.extent.size)
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimension,
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }

        return ImageSourcePreview(image: thumbnail, orientedPixelSize: orientedSize)
    }
}
