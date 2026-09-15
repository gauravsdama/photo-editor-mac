import AppKit
import Foundation

@MainActor
final class AppModel: ObservableObject {
    static let shared = AppModel()
    static let actionAPIPort: UInt16 = 4777

    @Published var gpuStatus: GPUStatus = .unknown
    @Published var selectedImage: NSImage?
    @Published var adjustedPreviewImage: NSImage?
    @Published var selectedImageName = "No image selected"
    @Published var selectedImagePath: String?
    @Published var selectedImageSize: CGSize?
    @Published var beforeAfterComparison: BeforeAfterComparison?
    @Published var isImportingImage = false
    @Published var adjustments = AdjustmentState()
    @Published var visibleAdjustmentControlIDs = AdjustmentControl.defaultVisibleIDs
    @Published var actionAPIStatus = "Automation API off"
    @Published var commandLog: [CommandLogEntry] = []
    @Published var isRenderingPreview = false
    @Published var isExporting = false
    @Published var exportStatus = ""

    let omniGen = OmniGenService(repositoryPath: PhaseOnePaths.omniGen)
    private var actionAPIServer: LocalActionAPIServer?
    private var previewRenderTask: Task<Void, Never>?

    init() {
        guard ProcessInfo.processInfo.environment["PHOTO_EDITOR_ENABLE_ACTION_API"] == "1" else {
            return
        }

        let server = LocalActionAPIServer(port: Self.actionAPIPort) { [weak self] request in
            guard let self else {
                return ActionAPIResponse.error(statusCode: 503, message: "Photo editor app model is unavailable.")
            }
            return await self.handleActionAPIRequest(request)
        }

        actionAPIServer = server
        server.start()
        actionAPIStatus = "Action API listening at \(actionAPIBaseURL.absoluteString)"
        recordCommand("Action API started", detail: actionAPIBaseURL.absoluteString)
    }

    deinit {
        actionAPIServer?.stop()
    }

    var actionAPIBaseURL: URL {
        URL(string: "http://127.0.0.1:\(Self.actionAPIPort)")!
    }

    var visibleAdjustmentControls: [AdjustmentControl] {
        AdjustmentControl.allCases.filter { visibleAdjustmentControlIDs.contains($0.rawValue) }
    }

    func refreshGPUStatus() {
        gpuStatus = GPUStatus.detect()
        recordCommand("GPU status refreshed", detail: gpuStatus.deviceName)
    }

    @discardableResult
    func loadImage(from url: URL) async -> Bool {
        guard let loadedImage = await readImage(from: url) else {
            selectedImage = nil
            selectedImageName = "Could not open \(url.lastPathComponent)"
            selectedImagePath = nil
            selectedImageSize = nil
            beforeAfterComparison = nil
            recordCommand("Image open failed", detail: url.path)
            return false
        }

        selectedImage = loadedImage.image
        adjustedPreviewImage = loadedImage.image
        selectedImageName = loadedImage.name
        selectedImagePath = loadedImage.path
        selectedImageSize = loadedImage.size
        beforeAfterComparison = nil
        exportStatus = ""
        recordCommand("Image opened", detail: "\(loadedImage.name) • \(Int(loadedImage.size.width))x\(Int(loadedImage.size.height))")
        schedulePreviewRender()
        return true
    }

    @discardableResult
    func showBeforeAfter(before beforeURL: URL, after afterURL: URL) async -> Bool {
        guard let before = await readImage(from: beforeURL), let after = await readImage(from: afterURL) else {
            recordCommand("Before/after failed", detail: "Could not load comparison images.")
            return false
        }

        beforeAfterComparison = BeforeAfterComparison(before: before, after: after)
        selectedImage = after.image
        adjustedPreviewImage = after.image
        selectedImageName = "Before/after comparison"
        selectedImagePath = after.path
        selectedImageSize = after.size
        recordCommand("Before/after shown", detail: "\(before.name) -> \(after.name)")
        return true
    }

    func clearWorkspace() {
        selectedImage = nil
        adjustedPreviewImage = nil
        selectedImageName = "No image selected"
        selectedImagePath = nil
        selectedImageSize = nil
        beforeAfterComparison = nil
        adjustments.reset()
        previewRenderTask?.cancel()
        isRenderingPreview = false
        exportStatus = ""
        recordCommand("Workspace cleared")
    }

    func clearCommandLog() {
        commandLog.removeAll()
    }

    func showDefaultAdjustmentControls() {
        visibleAdjustmentControlIDs = AdjustmentControl.defaultVisibleIDs
        recordCommand("Visible controls updated", detail: "Main \(visibleAdjustmentControlIDs.count)")
    }

    func showAllAdjustmentControls() {
        visibleAdjustmentControlIDs = Set(AdjustmentControl.allCases.map(\.rawValue))
        recordCommand("Visible controls updated", detail: "All \(visibleAdjustmentControlIDs.count)")
    }

    func setVisibleAdjustmentControls(_ controlIDs: [String]) {
        let validIDs = Set(AdjustmentControl.allCases.map(\.rawValue))
        let selectedIDs = Set(controlIDs).intersection(validIDs)
        visibleAdjustmentControlIDs = selectedIDs.isEmpty ? AdjustmentControl.defaultVisibleIDs : selectedIDs
        recordCommand("Visible controls updated", detail: "\(visibleAdjustmentControlIDs.count) controls")
    }

    func setAdjustmentControl(_ control: AdjustmentControl, isVisible: Bool) {
        if isVisible {
            visibleAdjustmentControlIDs.insert(control.rawValue)
        } else {
            visibleAdjustmentControlIDs.remove(control.rawValue)
        }
        recordCommand("Visible controls updated", detail: "\(visibleAdjustmentControlIDs.count) controls")
    }

    func resetAdjustments() {
        adjustments.reset()
        recordCommand("Adjustments reset")
        schedulePreviewRender()
    }

    func setAdjustmentValue(_ value: Double, for control: AdjustmentControl) {
        adjustments.setValue(value, for: control)
        schedulePreviewRender()
    }

    func setAdjustments(apiValues: [String: Any]) {
        adjustments.apply(apiValues: apiValues)
        schedulePreviewRender()
        let formatted = apiValues
            .compactMap { entry -> (key: String, value: Double)? in
                let key = entry.key
                let value = entry.value
                guard AdjustmentControl(rawValue: key) != nil else {
                    return nil
                }
                if let value = value as? Double {
                    return (key, value)
                }
                if let value = value as? Int {
                    return (key, Double(value))
                }
                if let value = value as? NSNumber {
                    return (key, value.doubleValue)
                }
                return nil
            }
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\(String(format: "%.2f", $0.value))" }
            .joined(separator: ", ")
        recordCommand("Adjustments updated", detail: formatted.isEmpty ? nil : formatted)
    }

    func exportAdjustedImage(to outputURL: URL, quality: Double) async throws -> ImageExportResult {
        guard let selectedImagePath else {
            throw ImageExportError.noImageLoaded
        }

        let result = try await ImageExporter.exportAdjustedImage(
            sourcePath: selectedImagePath,
            outputPath: outputURL.path,
            adjustments: adjustments,
            quality: quality
        )
        recordCommand("Image exported", detail: outputURL.lastPathComponent)
        return result
    }

    func exportPhoto(to outputURL: URL) async {
        isExporting = true
        exportStatus = "Exporting…"
        defer { isExporting = false }
        do {
            _ = try await exportAdjustedImage(to: outputURL, quality: 0.94)
            exportStatus = "Exported \(outputURL.lastPathComponent)"
        } catch {
            exportStatus = error.localizedDescription
        }
    }

    func recordCommand(_ title: String, detail: String? = nil) {
        commandLog.insert(CommandLogEntry(title: title, detail: detail), at: 0)
        if commandLog.count > 40 {
            commandLog.removeLast(commandLog.count - 40)
        }
    }

    private func readImage(from url: URL) async -> LoadedImageFile? {
        let imageData = await Task.detached(priority: .userInitiated) {
            try? Data(contentsOf: url, options: [.mappedIfSafe])
        }.value

        guard let imageData, let image = NSImage(data: imageData) else {
            return nil
        }

        return LoadedImageFile(
            image: image,
            name: url.lastPathComponent,
            path: url.path,
            size: image.size
        )
    }


    private func schedulePreviewRender() {
        guard let selectedImagePath, beforeAfterComparison == nil else {
            return
        }

        previewRenderTask?.cancel()
        let sourcePath = selectedImagePath
        let currentAdjustments = adjustments
        isRenderingPreview = true
        previewRenderTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(80))
            guard !Task.isCancelled else { return }

            let preview = try? await ImageExporter.renderAdjustedPreview(
                sourcePath: sourcePath,
                adjustments: currentAdjustments,
                maxDimension: 2400
            )
            guard !Task.isCancelled, let self, self.selectedImagePath == sourcePath else {
                return
            }
            if let preview {
                self.adjustedPreviewImage = preview
            }
            self.isRenderingPreview = false
        }
    }
}

struct LoadedImageFile {
    let image: NSImage
    let name: String
    let path: String
    let size: CGSize

    var apiRepresentation: [String: Any] {
        [
            "name": name,
            "path": path,
            "width": size.width,
            "height": size.height
        ]
    }
}

struct BeforeAfterComparison {
    let before: LoadedImageFile
    let after: LoadedImageFile

    var apiRepresentation: [String: Any] {
        [
            "before": before.apiRepresentation,
            "after": after.apiRepresentation
        ]
    }
}

enum PhaseOnePaths {
    static let phaseRoot = ProcessInfo.processInfo.environment["PHOTO_EDITOR_PHASE_ROOT"]
        .map { URL(fileURLWithPath: $0, isDirectory: true) }
    static let rapidRAW = phaseRoot?.appendingPathComponent("RapidRAW", isDirectory: true)
    static let tuiImageEditor = phaseRoot?.appendingPathComponent("tui.image-editor", isDirectory: true)
    static let omniGen = phaseRoot?.appendingPathComponent("OmniGen", isDirectory: true)
}
