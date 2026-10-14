import AppKit
import Foundation

@MainActor
final class AppModel: ObservableObject {
    static let shared = AppModel()
    static let actionAPIPort: UInt16 = 4777
    static let previewMaximumDimension: CGFloat = 2_400

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
    @Published var exportFormat: RenderedExportFormat = .tiffFloat32
    @Published var editsStatus = ""
    @Published var isSavingEdits = false
    @Published private(set) var isRAWSource = false
    @Published private(set) var projectURL: URL?
    private var savedAdjustments: [String: Double]?
    private var savedExportFormat: RenderedExportFormat?

    var hasUnsavedEdits: Bool {
        selectedImagePath != nil && (adjustments.apiRepresentation != (savedAdjustments ?? AdjustmentState().apiRepresentation)
            || (savedExportFormat != nil && savedExportFormat != exportFormat))
    }

    private var actionAPIServer: LocalActionAPIServer?
    private(set) var actionAPIBearerToken: String?
    private var previewRenderTask: Task<Void, Never>?
    private var previewRenderGeneration = 0
    private var imageLoadGeneration = 0

    init() {
        guard ProcessInfo.processInfo.environment["PHOTO_EDITOR_ENABLE_ACTION_API"] == "1" else {
            return
        }

        let token = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
        actionAPIBearerToken = token
        fputs("PhotoEditorMac action API bearer token: \(token)\n", stderr)
        let server = LocalActionAPIServer(
            port: Self.actionAPIPort,
            bearerToken: token,
            readinessHandler: { [weak self] isReady in
                Task { @MainActor [weak self] in
                    guard let self else {
                        return
                    }
                    if isReady {
                        self.actionAPIStatus = "Action API listening at \(self.actionAPIBaseURL.absoluteString)"
                        self.recordCommand("Action API started", detail: self.actionAPIBaseURL.absoluteString)
                    } else {
                        self.actionAPIStatus = "Automation API off"
                    }
                }
            }
        ) { [weak self] request in
            guard let self else {
                return ActionAPIResponse.error(statusCode: 503, message: "Photo editor app model is unavailable.")
            }
            return await self.handleActionAPIRequest(request)
        }

        actionAPIServer = server
        server.start()
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
    func loadImage(from url: URL, restoringEdits: Bool = true) async -> Bool {
        let generation = beginImageLoad()
        guard let loadedImage = await readImage(from: url) else {
            guard imageLoadGeneration == generation else {
                return false
            }
            selectedImage = nil
            adjustedPreviewImage = nil
            selectedImageName = "Could not open \(url.lastPathComponent)"
            selectedImagePath = nil
            selectedImageSize = nil
            beforeAfterComparison = nil
            isRAWSource = false
            projectURL = nil
            savedAdjustments = nil
            savedExportFormat = nil
            editsStatus = PhotoSource.isRAW(url) ? "The RAW sensor data could not be decoded on this Mac." : ""
            recordCommand("Image open failed", detail: url.path)
            return false
        }
        guard imageLoadGeneration == generation else {
            return false
        }

        selectedImage = loadedImage.image
        adjustedPreviewImage = loadedImage.image
        selectedImageName = loadedImage.name
        selectedImagePath = loadedImage.path
        selectedImageSize = loadedImage.size
        beforeAfterComparison = nil
        adjustments.reset()
        isRAWSource = PhotoSource.isRAW(url)
        projectURL = nil
        savedAdjustments = nil
        savedExportFormat = nil
        editsStatus = ""
        exportStatus = ""
        recordCommand("Image opened", detail: "\(loadedImage.name) • \(Int(loadedImage.size.width))x\(Int(loadedImage.size.height))")
        if restoringEdits {
            let sidecars = [url.appendingPathExtension("xmp"), url.deletingPathExtension().appendingPathExtension("xmp")]
            if let sidecar = sidecars.first(where: { FileManager.default.fileExists(atPath: $0.path) }) {
                do {
                    let project = try await Task.detached { try PhotoProjectStore.load(sidecar) }.value
                    guard imageLoadGeneration == generation else { return false }
                    guard project.sourceURL(relativeTo: sidecar).resolvingSymlinksInPath() == url.resolvingSymlinksInPath() else {
                        throw PhotoWorkflowError("The sidecar refers to a different original photograph.")
                    }
                    restore(project, document: sidecar)
                } catch {
                    guard imageLoadGeneration == generation else { return false }
                    editsStatus = error.localizedDescription
                }
            }
        }
        schedulePreviewRender()
        return true
    }

    @discardableResult
    func showBeforeAfter(before beforeURL: URL, after afterURL: URL) async -> Bool {
        let generation = beginImageLoad()
        async let beforePreview = ImageSourceLoader.loadPreview(
            from: beforeURL,
            maxDimension: Self.previewMaximumDimension
        )
        async let afterPreview = ImageSourceLoader.loadPreview(
            from: afterURL,
            maxDimension: Self.previewMaximumDimension
        )
        guard let beforeSource = await beforePreview,
              let afterSource = await afterPreview,
              imageLoadGeneration == generation else {
            guard imageLoadGeneration == generation else {
                return false
            }
            recordCommand("Before/after failed", detail: "Could not load comparison images.")
            return false
        }
        let before = loadedImage(from: beforeSource, sourceURL: beforeURL)
        let after = loadedImage(from: afterSource, sourceURL: afterURL)

        beforeAfterComparison = BeforeAfterComparison(before: before, after: after)
        selectedImage = after.image
        adjustedPreviewImage = after.image
        selectedImageName = "Before/after comparison"
        selectedImagePath = after.path
        selectedImageSize = after.size
        isRAWSource = PhotoSource.isRAW(afterURL)
        projectURL = nil
        savedAdjustments = nil
        savedExportFormat = nil
        editsStatus = ""
        recordCommand("Before/after shown", detail: "\(before.name) -> \(after.name)")
        return true
    }

    func clearWorkspace() {
        imageLoadGeneration += 1
        selectedImage = nil
        adjustedPreviewImage = nil
        selectedImageName = "No image selected"
        selectedImagePath = nil
        selectedImageSize = nil
        beforeAfterComparison = nil
        adjustments.reset()
        cancelPreviewRender()
        exportStatus = ""
        editsStatus = ""
        projectURL = nil
        savedAdjustments = nil
        savedExportFormat = nil
        isRAWSource = false
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

    func setAdjustments(apiValues: JSONObject) {
        adjustments.apply(apiValues: apiValues)
        schedulePreviewRender()
        let formatted = apiValues
            .compactMap { entry -> (key: String, value: Double)? in
                let key = entry.key
                guard AdjustmentControl(rawValue: key) != nil else {
                    return nil
                }
                return entry.value.numberValue.map { (key, $0) }
            }
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\(String(format: "%.2f", $0.value))" }
            .joined(separator: ", ")
        recordCommand("Adjustments updated", detail: formatted.isEmpty ? nil : formatted)
    }

    func exportAdjustedImage(to outputURL: URL, quality: Double = ImageExporter.maximumJPEGQuality, format: RenderedExportFormat? = nil) async throws -> ImageExportResult {
        guard let selectedImagePath else {
            throw ImageExportError.noImageLoaded
        }

        let result = try await ImageExporter.exportAdjustedImage(
            sourcePath: selectedImagePath,
            outputPath: outputURL.path,
            adjustments: adjustments,
            quality: quality,
            format: format
        )
        recordCommand("Image exported", detail: outputURL.lastPathComponent)
        return result
    }

    func exportPhoto(to outputURL: URL) async {
        isExporting = true
        exportStatus = "Exporting…"
        defer { isExporting = false }
        do {
            _ = try await exportAdjustedImage(to: outputURL, format: exportFormat)
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

    func saveEdits(to document: URL) async throws {
        guard let selectedImagePath, beforeAfterComparison == nil else { throw ImageExportError.noImageLoaded }
        let source = URL(fileURLWithPath: selectedImagePath)
        let snapshot = adjustments.apiRepresentation
        let format = exportFormat
        let generation = imageLoadGeneration
        isSavingEdits = true
        defer { isSavingEdits = false }
        try await Task.detached {
            try PhotoProjectStore.save(source: source, document: document, adjustments: snapshot, format: format)
        }.value
        guard generation == imageLoadGeneration else { return }
        projectURL = document
        savedAdjustments = snapshot
        savedExportFormat = format
        editsStatus = "Saved edits for \(source.lastPathComponent)"
    }

    @discardableResult
    func openEdits(from document: URL) async -> Bool {
        do {
            let generation = imageLoadGeneration
            let project = try await Task.detached { try PhotoProjectStore.load(document) }.value
            guard generation == imageLoadGeneration else { return false }
            guard await loadImage(from: project.sourceURL(relativeTo: document), restoringEdits: false) else { return false }
            restore(project, document: document)
            schedulePreviewRender()
            return true
        } catch {
            editsStatus = error.localizedDescription
            return false
        }
    }

    private func restore(_ project: PhotoProject, document: URL) {
        adjustments.reset()
        adjustments.apply(apiValues: project.adjustments.mapValues(JSONValue.number))
        exportFormat = project.exportFormat
        savedAdjustments = adjustments.apiRepresentation
        savedExportFormat = project.exportFormat
        projectURL = document
        editsStatus = "Edits saved"
    }

    func confirmDiscardEdits() -> Bool {
        guard hasUnsavedEdits else { return true }
        let alert = NSAlert()
        alert.messageText = "Discard unsaved edits?"
        alert.informativeText = "Save your edits first if you want to continue editing this photograph later."
        alert.addButton(withTitle: "Keep editing")
        alert.addButton(withTitle: "Discard edits")
        return alert.runModal() == .alertSecondButtonReturn
    }

    private func readImage(from url: URL) async -> LoadedImageFile? {
        guard let preview = await ImageSourceLoader.loadPreview(
            from: url,
            maxDimension: Self.previewMaximumDimension
        ) else {
            return nil
        }
        return loadedImage(from: preview, sourceURL: url)
    }

    private func loadedImage(from preview: ImageSourcePreview, sourceURL: URL) -> LoadedImageFile {
        let image = NSImage(
            cgImage: preview.image,
            size: NSSize(width: preview.image.width, height: preview.image.height)
        )

        return LoadedImageFile(
            image: image,
            name: sourceURL.lastPathComponent,
            path: sourceURL.path,
            size: preview.orientedPixelSize
        )
    }

    private func beginImageLoad() -> Int {
        imageLoadGeneration += 1
        cancelPreviewRender()
        return imageLoadGeneration
    }

    private func schedulePreviewRender() {
        guard let selectedImagePath, beforeAfterComparison == nil else {
            return
        }

        cancelPreviewRender()
        let generation = previewRenderGeneration
        let sourcePath = selectedImagePath
        let currentAdjustments = adjustments
        isRenderingPreview = true
        previewRenderTask = Task { [weak self] in
            defer {
                if let self, self.previewRenderGeneration == generation {
                    self.previewRenderTask = nil
                    self.isRenderingPreview = false
                }
            }

            do {
                try await Task.sleep(for: .milliseconds(80))
                let rendered = try await ImageExporter.renderAdjustedPreview(
                    sourcePath: sourcePath,
                    adjustments: currentAdjustments,
                    maxDimension: Self.previewMaximumDimension
                )
                try Task.checkCancellation()
                guard let self,
                      self.previewRenderGeneration == generation,
                      self.selectedImagePath == sourcePath,
                      self.beforeAfterComparison == nil else {
                    return
                }
                self.adjustedPreviewImage = NSImage(
                    cgImage: rendered,
                    size: NSSize(width: rendered.width, height: rendered.height)
                )
            } catch is CancellationError {
                return
            } catch {
                return
            }
        }
    }

    private func cancelPreviewRender() {
        previewRenderGeneration += 1
        previewRenderTask?.cancel()
        previewRenderTask = nil
        isRenderingPreview = false
    }
}

struct LoadedImageFile {
    let image: NSImage
    let name: String
    let path: String
    let size: CGSize

    var apiRepresentation: JSONObject {
        [
            "name": .string(name),
            "width": .number(Double(size.width)),
            "height": .number(Double(size.height))
        ]
    }
}

struct BeforeAfterComparison {
    let before: LoadedImageFile
    let after: LoadedImageFile

    var apiRepresentation: JSONObject {
        [
            "before": .object(before.apiRepresentation),
            "after": .object(after.apiRepresentation)
        ]
    }
}
