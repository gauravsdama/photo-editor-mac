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
            try auditAccessibility(from: window)

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

    private static func auditAccessibility(from root: AnyObject) throws {
        var pending: [AnyObject] = [root]
        var visited = Set<ObjectIdentifier>()
        var auditedElementCount = 0
        let labeledRoles: Set<NSAccessibility.Role> = [.button, .checkBox, .radioButton, .slider]

        while let object = pending.popLast() {
            let identifier = ObjectIdentifier(object)
            guard visited.insert(identifier).inserted,
                  let values = accessibilityValues(for: object) else { continue }
            auditedElementCount += 1

            let frame = values.frame
            guard frame.origin.x.isFinite, frame.origin.y.isFinite,
                  frame.width.isFinite, frame.height.isFinite else {
                throw SmokeError("an accessibility element has a non-finite frame")
            }

            if let role = values.role, labeledRoles.contains(role) {
                let label = values.label?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let title = values.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                guard !label.isEmpty || !title.isEmpty else {
                    throw SmokeError("an interactive accessibility element is missing a label")
                }
            }

            for child in values.children {
                if let child = child as AnyObject? { pending.append(child) }
            }
        }

        guard auditedElementCount > 0 else {
            throw SmokeError("the accessibility tree could not be inspected")
        }
    }

    private static func accessibilityValues(
        for object: AnyObject
    ) -> (frame: NSRect, role: NSAccessibility.Role?, label: String?, title: String?, children: [Any])? {
        if let view = object as? NSView {
            let children = NSAccessibility.unignoredChildren(
                from: (view.accessibilityChildren() ?? []) + view.subviews
            )
            return (view.accessibilityFrame(), view.accessibilityRole(), view.accessibilityLabel(),
                    view.accessibilityTitle(), children)
        }
        if let window = object as? NSWindow {
            var children = window.accessibilityChildren() ?? []
            if let contentView = window.contentView { children.append(contentView) }
            children = NSAccessibility.unignoredChildren(from: children)
            return (window.accessibilityFrame(), window.accessibilityRole(), window.accessibilityLabel(),
                    window.accessibilityTitle(), children)
        }
        if let element = object as? NSAccessibilityElement {
            return (element.accessibilityFrame(), element.accessibilityRole(), element.accessibilityLabel(),
                    element.accessibilityTitle(), element.accessibilityChildren() ?? [])
        }
        return nil
    }

    private struct SmokeError: LocalizedError {
        let message: String

        init(_ message: String) {
            self.message = message
        }

        var errorDescription: String? { message }
    }
}
