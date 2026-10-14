import CoreImage
import Foundation
import Testing
@testable import PhaseOnePhotoEditor

@Suite("Performance benchmarks")
struct PerformanceBenchmarks {
    @Test("Import, preview, slider, export, and lifecycle measurements")
    @MainActor
    func workflowMeasurements() async throws {
        guard ProcessInfo.processInfo.environment["PHOTO_EDITOR_RUN_BENCHMARKS"] == "1" else {
            return
        }

        let workspace = FileManager.default.temporaryDirectory
            .appendingPathComponent("photo-editor-benchmark-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: workspace) }

        let fixtures = [
            ("12mp", 4_000, 3_000),
            ("24mp", 6_000, 4_000),
            ("50mp", 10_000, 5_000)
        ]
        var fixtureURLs: [URL] = []
        for (name, width, height) in fixtures {
            let url = workspace.appendingPathComponent("\(name).jpg")
            try writeJPEG(width: width, height: height, to: url)
            fixtureURLs.append(url)
        }

        for (index, fixture) in fixtureURLs.enumerated() {
            let model = AppModel()
            let (_, duration) = try await measure {
                try #require(await model.loadImage(from: fixture))
            }
            report("import_\(fixtures[index].0)", duration)
        }

        var adjustments = AdjustmentState()
        adjustments.setValue(0.8, for: .exposure)
        let (_, previewDuration) = try await measure {
            try await ImageExporter.renderAdjustedPreview(
                sourcePath: fixtureURLs[1].path,
                adjustments: adjustments,
                maxDimension: AppModel.previewMaximumDimension
            )
        }
        report("first_adjusted_preview_24mp", previewDuration)

        let sliderModel = AppModel()
        try #require(await sliderModel.loadImage(from: fixtureURLs[1]))
        let (_, sliderDuration) = try await measure {
            for step in 0..<60 {
                sliderModel.setAdjustmentValue(Double(step % 40) / 10 - 2, for: .exposure)
            }
            let deadline = ContinuousClock.now.advanced(by: .seconds(10))
            while sliderModel.isRenderingPreview && ContinuousClock.now < deadline {
                try await Task.sleep(for: .milliseconds(10))
            }
            try #require(!sliderModel.isRenderingPreview)
        }
        report("rapid_slider_60_updates", sliderDuration)

        let output = workspace.appendingPathComponent("export.jpg")
        let (_, exportDuration) = try await measure {
            try await ImageExporter.exportAdjustedImage(
                sourcePath: fixtureURLs[1].path,
                outputPath: output.path,
                adjustments: adjustments,
                quality: 0.94
            )
        }
        report("export_24mp", exportDuration)

        let lifecycleModel = AppModel()
        let (_, lifecycleDuration) = try await measure {
            for _ in 0..<10 {
                try #require(await lifecycleModel.loadImage(from: fixtureURLs[0]))
                lifecycleModel.clearWorkspace()
            }
        }
        report("open_clear_10_cycles", lifecycleDuration)

        try renderBackendMeasurements()
    }

    @MainActor
    private func measure<T: Sendable>(_ operation: () async throws -> T) async rethrows -> (T, Duration) {
        let clock = ContinuousClock()
        let start = clock.now
        let value = try await operation()
        return (value, start.duration(to: clock.now))
    }

    @MainActor
    private func report(_ name: String, _ duration: Duration) {
        let components = duration.components
        let milliseconds = Double(components.seconds) * 1_000
            + Double(components.attoseconds) / 1_000_000_000_000_000
        print("BENCHMARK \(name) \(String(format: "%.2f", milliseconds)) ms")
    }

    @MainActor
    private func renderBackendMeasurements() throws {
        let image = CIImage(color: CIColor(red: 0.2, green: 0.4, blue: 0.7))
            .cropped(to: CGRect(x: 0, y: 0, width: 2_400, height: 1_600))
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
        for (name, context) in [
            ("default", CIContext()),
            ("software", CIContext(options: [.useSoftwareRenderer: true]))
        ] {
            let clock = ContinuousClock()
            let start = clock.now
            _ = try #require(
                context.createCGImage(image, from: image.extent, format: .RGBA8, colorSpace: colorSpace)
            )
            report("render_backend_\(name)", start.duration(to: clock.now))
        }
    }

    private func writeJPEG(width: Int, height: Int, to url: URL) throws {
        let image = CIImage(color: CIColor(red: 0.24, green: 0.48, blue: 0.72))
            .cropped(to: CGRect(x: 0, y: 0, width: width, height: height))
        let context = CIContext(options: [.useSoftwareRenderer: true])
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
        guard let data = context.jpegRepresentation(of: image, colorSpace: colorSpace) else {
            throw CocoaError(.fileWriteUnknown)
        }
        try data.write(to: url, options: .atomic)
    }
}
