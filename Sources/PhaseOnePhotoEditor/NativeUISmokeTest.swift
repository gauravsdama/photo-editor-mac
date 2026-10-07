import AppKit
import CoreImage
import Foundation

@MainActor
enum NativeUISmokeTest {
    static func run(window: NSWindow, model: AppModel) async -> Bool {
        do {
            try await Task.sleep(for: .milliseconds(200))
            guard window.isVisible, window.contentView != nil else {
                throw SmokeError("window did not become visible")
            }

            window.setContentSize(NSSize(width: 1_120, height: 720))
            window.displayIfNeeded()
            guard window.contentLayoutRect.width >= 1_100,
                  window.contentLayoutRect.height >= 700 else {
                throw SmokeError("window did not honor its minimum layout size")
            }
            window.recalculateKeyViewLoop()
            guard window.makeFirstResponder(window.contentView) else {
                throw SmokeError("window could not establish keyboard focus")
            }

            let workspace = FileManager.default.temporaryDirectory
                .appendingPathComponent("photo-editor-ui-smoke-\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: workspace) }

            let longName = String(repeating: "long-photo-name-", count: 8) + ".jpg"
            let source = workspace.appendingPathComponent(longName)
            let output = workspace.appendingPathComponent("edited.tiff")
            let corrupt = workspace.appendingPathComponent("corrupt.jpg")
            try writeJPEG(width: 1_600, height: 1_000, to: source)
            try Data("not an image".utf8).write(to: corrupt)

            guard await model.loadImage(from: source),
                  model.selectedImageName == longName,
                  model.selectedImage != nil else {
                throw SmokeError("open workflow failed")
            }
            model.setAdjustmentValue(0.8, for: .exposure)
            let renderDeadline = ContinuousClock.now.advanced(by: .seconds(10))
            while model.isRenderingPreview && ContinuousClock.now < renderDeadline {
                try await Task.sleep(for: .milliseconds(10))
            }
            guard !model.isRenderingPreview, model.adjustedPreviewImage != nil else {
                throw SmokeError("adjusted preview did not settle")
            }

            let project = source.appendingPathExtension("photoedit")
            try await model.saveEdits(to: project)
            model.clearWorkspace()
            guard await model.openEdits(from: project), model.adjustments.value(for: .exposure) == 0.8 else {
                throw SmokeError("saved project did not restore the original and edits")
            }

            await model.exportPhoto(to: output)
            guard FileManager.default.fileExists(atPath: output.path),
                  model.exportStatus == "Exported \(output.lastPathComponent)" else {
                throw SmokeError("export workflow failed")
            }
            guard await model.showBeforeAfter(before: source, after: output),
                  model.beforeAfterComparison != nil else {
                throw SmokeError("before/after workflow failed")
            }

            model.resetAdjustments()
            guard model.adjustments.value(for: .exposure) == AdjustmentControl.exposure.defaultValue else {
                throw SmokeError("reset workflow failed")
            }
            model.clearWorkspace()
            guard model.selectedImage == nil, model.beforeAfterComparison == nil else {
                throw SmokeError("clear workflow failed")
            }
            guard !(await model.loadImage(from: corrupt)), model.selectedImage == nil else {
                throw SmokeError("corrupt-input recovery failed")
            }
            guard AdjustmentControl.allCases.allSatisfy({ !$0.title.isEmpty }) else {
                throw SmokeError("an adjustment is missing an accessibility-facing label")
            }

            print("Native UI smoke test passed")
            return true
        } catch {
            fputs("Native UI smoke test failed: \(error.localizedDescription)\n", stderr)
            return false
        }
    }

    private static func writeJPEG(width: Int, height: Int, to url: URL) throws {
        let image = CIImage(color: CIColor(red: 0.24, green: 0.48, blue: 0.72))
            .cropped(to: CGRect(x: 0, y: 0, width: width, height: height))
        let context = CIContext(options: [.useSoftwareRenderer: true])
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
        guard let data = context.jpegRepresentation(of: image, colorSpace: colorSpace) else {
            throw SmokeError("could not create the temporary JPEG fixture")
        }
        try data.write(to: url, options: .atomic)
    }

    private struct SmokeError: LocalizedError {
        let message: String

        init(_ message: String) {
            self.message = message
        }

        var errorDescription: String? { message }
    }
}
