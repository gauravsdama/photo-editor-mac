import CoreImage
import Foundation
import Testing
@testable import PhaseOnePhotoEditor

@Suite("Image filter graph")
struct ImageFilterGraphTests {
    private let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!

    @Test("Neutral adjustments preserve pixels within rendering tolerance")
    func neutralAdjustmentsPreservePixels() throws {
        let fixture = makeFixture()
        let input = try render(fixture)
        let output = try render(apply(AdjustmentState(), to: fixture))

        #expect(input.count == output.count)
        #expect(zip(input, output).allSatisfy { abs(Int($0) - Int($1)) <= 2 })
    }

    @Test("Every adjustment preserves the source extent")
    func adjustmentsPreserveExtent() {
        let fixture = makeFixture()

        for control in AdjustmentControl.allCases {
            var adjustments = AdjustmentState()
            let testValue = control.defaultValue == control.range.upperBound
                ? control.range.lowerBound
                : control.range.upperBound
            adjustments.setValue(testValue, for: control)
            if control == .vignetteRadius {
                adjustments.setValue(1, for: .vignette)
            } else if control == .bloomRadius {
                adjustments.setValue(1, for: .bloom)
            }
            let output = apply(adjustments, to: fixture)
            #expect(output.extent == fixture.extent, "Extent changed for \(control.rawValue)")
        }
    }

    @Test("Every active adjustment changes a varied fixture")
    func activeAdjustmentsChangePixels() throws {
        let fixture = makeFixture()
        let neutral = try render(apply(AdjustmentState(), to: fixture))
        let values: [(AdjustmentControl, Double)] = [
            (.exposure, 1), (.brightness, 0.5), (.contrast, 0.5), (.saturation, 0),
            (.vibrance, 1), (.highlights, 1), (.shadows, 1), (.temperature, 100),
            (.tint, 100), (.sharpness, 2), (.clarity, 2), (.noiseReduction, 1),
            (.gamma, 2), (.hue, 90), (.sepia, 1), (.monochrome, 1),
            (.vignette, 2), (.blur, 10), (.redBalance, 1),
            (.greenBalance, 1), (.blueBalance, 1), (.blackLevel, 0.5), (.whiteLevel, 0.5)
        ]

        for (control, value) in values {
            var adjustments = AdjustmentState()
            adjustments.setValue(value, for: control)
            let adjusted = try render(apply(adjustments, to: fixture))
            let changedChannels = zip(neutral, adjusted).filter { $0 != $1 }.count
            #expect(changedChannels > 0, "No rendered change for \(control.rawValue)")
        }
    }

    @Test("Bidirectional tone controls move luminance in the expected direction")
    func toneControlDirections() throws {
        let fixture = makeFixture()

        for control in [AdjustmentControl.exposure, .brightness] {
            var lower = AdjustmentState()
            lower.setValue(control.range.lowerBound / 2, for: control)
            var upper = AdjustmentState()
            upper.setValue(control.range.upperBound / 2, for: control)

            let lowerLuminance = averageLuminance(try render(apply(lower, to: fixture)))
            let upperLuminance = averageLuminance(try render(apply(upper, to: fixture)))
            #expect(lowerLuminance < upperLuminance, "Unexpected direction for \(control.rawValue)")
        }

        var lowerGamma = AdjustmentState()
        lowerGamma.setValue(0.5, for: .gamma)
        var upperGamma = AdjustmentState()
        upperGamma.setValue(2, for: .gamma)
        #expect(
            averageLuminance(try render(apply(lowerGamma, to: fixture)))
                > averageLuminance(try render(apply(upperGamma, to: fixture)))
        )
    }

    @Test("Channel balance controls affect their named channel")
    func channelBalanceDirections() throws {
        let fixture = makeFixture()
        let controls: [(AdjustmentControl, Int)] = [(.redBalance, 0), (.greenBalance, 1), (.blueBalance, 2)]

        for (control, channel) in controls {
            var lower = AdjustmentState()
            lower.setValue(-1, for: control)
            var upper = AdjustmentState()
            upper.setValue(1, for: control)
            let lowerMean = channelMean(try render(apply(lower, to: fixture)), channel: channel)
            let upperMean = channelMean(try render(apply(upper, to: fixture)), channel: channel)
            #expect(lowerMean < upperMean, "Unexpected direction for \(control.rawValue)")
        }
    }

    @Test("Blur and bloom remain bounded to the input extent")
    func spatialEffectsRemainBounded() {
        let fixture = makeFixture()
        for control in [AdjustmentControl.blur, .bloom] {
            var adjustments = AdjustmentState()
            adjustments.setValue(control.range.upperBound, for: control)
            let output = apply(adjustments, to: fixture)
            #expect(output.extent == fixture.extent)
            #expect(!output.extent.isInfinite)
        }
    }

    @Test("Bloom spreads a bright region without expanding the canvas")
    func bloomChangesBrightFixture() throws {
        let fixture = makeBloomFixture()
        var adjustments = AdjustmentState()
        adjustments.setValue(1, for: .bloom)
        adjustments.setValue(8, for: .bloomRadius)
        let outputImage = apply(adjustments, to: fixture)

        #expect(outputImage.extent == fixture.extent)
        #expect(try render(outputImage) != render(fixture))
    }

    private func apply(_ adjustments: AdjustmentState, to image: CIImage) -> CIImage {
        ImageFilterGraph.apply(adjustments: adjustments, to: image, originalExtent: image.extent)
    }

    private func makeFixture(width: Int = 16, height: Int = 16) -> CIImage {
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        for y in 0..<height {
            for x in 0..<width {
                let offset = (y * width + x) * 4
                pixels[offset] = UInt8(32 + x * 12)
                pixels[offset + 1] = UInt8(40 + y * 11)
                pixels[offset + 2] = (x + y).isMultiple(of: 2) ? 48 : 208
                pixels[offset + 3] = 255
            }
        }
        return pixels.withUnsafeBytes { bytes in
            CIImage(
                bitmapData: Data(bytes),
                bytesPerRow: width * 4,
                size: CGSize(width: width, height: height),
                format: .RGBA8,
                colorSpace: colorSpace
            )
        }
    }

    private func makeBloomFixture() -> CIImage {
        let width = 64
        let height = 64
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        for y in 0..<height {
            for x in 0..<width {
                let offset = (y * width + x) * 4
                let isCenter = (28..<36).contains(x) && (28..<36).contains(y)
                pixels[offset] = isCenter ? 255 : 0
                pixels[offset + 1] = isCenter ? 255 : 0
                pixels[offset + 2] = isCenter ? 255 : 0
                pixels[offset + 3] = 255
            }
        }
        return CIImage(
            bitmapData: Data(pixels),
            bytesPerRow: width * 4,
            size: CGSize(width: width, height: height),
            format: .RGBA8,
            colorSpace: colorSpace
        )
    }

    private func render(_ image: CIImage) throws -> [UInt8] {
        let width = Int(image.extent.width)
        let height = Int(image.extent.height)
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let context = CIContext(options: [
            .useSoftwareRenderer: true,
            .workingColorSpace: colorSpace,
            .outputColorSpace: colorSpace
        ])
        context.render(
            image,
            toBitmap: &pixels,
            rowBytes: width * 4,
            bounds: image.extent,
            format: .RGBA8,
            colorSpace: colorSpace
        )
        return pixels
    }

    private func averageLuminance(_ pixels: [UInt8]) -> Double {
        var total = 0.0
        for index in stride(from: 0, to: pixels.count, by: 4) {
            let red = Double(pixels[index])
            let green = Double(pixels[index + 1])
            let blue = Double(pixels[index + 2])
            total += 0.2126 * red + 0.7152 * green + 0.0722 * blue
        }
        return total / Double(pixels.count / 4)
    }

    private func channelMean(_ pixels: [UInt8], channel: Int) -> Double {
        var total = 0.0
        for index in stride(from: channel, to: pixels.count, by: 4) {
            total += Double(pixels[index])
        }
        return total / Double(pixels.count / 4)
    }
}
