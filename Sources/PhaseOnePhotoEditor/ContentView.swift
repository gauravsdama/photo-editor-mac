import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 260, ideal: 300, max: 360)
        } detail: {
            EditorWorkspaceView()
        }
        .fileImporter(
            isPresented: $model.isImportingImage,
            allowedContentTypes: [.image],
            allowsMultipleSelection: false
        ) { result in
            if case let .success(urls) = result, let url = urls.first {
                Task {
                    await model.loadImage(from: url)
                }
            }
        }
    }
}

private struct SidebarView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Photo Editor")
                    .font(.title2.weight(.semibold))
                Text("Local edits on your Mac")
                    .foregroundStyle(.secondary)
            }

            GPUStatusView(status: model.gpuStatus) {
                model.refreshGPUStatus()
            }

            Text(model.actionAPIStatus)
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            CommandLogView(entries: model.commandLog) {
                model.clearCommandLog()
            }

            Spacer()
        }
        .padding(18)
    }
}

private struct CommandLogView: View {
    let entries: [CommandLogEntry]
    let clear: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Automation history")
                    .font(.headline)
                Spacer()
                Button(action: clear) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .help("Clear command log")
                .disabled(entries.isEmpty)
            }

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    if entries.isEmpty {
                        Text("No edits from automation yet.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        ForEach(entries) { entry in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(alignment: .firstTextBaseline) {
                                    Text(entry.title)
                                        .font(.caption.weight(.semibold))
                                    Spacer()
                                    Text(entry.timestamp.formatted(date: .omitted, time: .shortened))
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                                if let detail = entry.detail {
                                    Text(detail)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                            }
                            .padding(8)
                            .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
            }
        }
        .frame(minHeight: 220)
    }
}

private struct GPUStatusView: View {
    let status: GPUStatus
    let refresh: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Rendering device")
                    .font(.headline)
                Spacer()
                Button("Check again", action: refresh)
                    .controlSize(.small)
            }

            Label(status.deviceName, systemImage: status.isAvailable ? "cpu" : "exclamationmark.triangle")
                .font(.subheadline)

            StatusRow(label: "Apple Silicon build", value: status.isAppleSiliconBuild)
            StatusRow(label: "Unified memory", value: status.hasUnifiedMemory)
            StatusRow(label: "Virtual GPU ready", value: status.looksLikeAppleSiliconVirtualGPU)

            Text(status.recommendedRenderingBackend)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(status.recommendedAIBackend)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(.background, in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct StatusRow: View {
    let label: String
    let value: Bool

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Image(systemName: value ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundStyle(value ? .green : .secondary)
        }
        .font(.caption)
    }
}

private struct EditorWorkspaceView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                ToolbarView()
                Divider()
                ImagePreviewView(
                    image: model.adjustedPreviewImage ?? model.selectedImage,
                    imageName: model.selectedImageName,
                    comparison: model.beforeAfterComparison
                )
            }

            Divider()

            AdjustmentPanelView()
                .frame(width: 280)
        }
    }
}

private struct ToolbarView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        HStack(spacing: 10) {
            Button {
                model.isImportingImage = true
            } label: {
                Label("Open photo…", systemImage: "photo")
            }

            Button {
                model.resetAdjustments()
            } label: {
                Label("Reset", systemImage: "arrow.counterclockwise")
            }
            .disabled(model.selectedImage == nil)

            Button {
                model.clearWorkspace()
            } label: {
                Label("Clear", systemImage: "xmark.circle")
            }
            .disabled(model.selectedImage == nil && model.beforeAfterComparison == nil)

            Button {
                exportPhoto()
            } label: {
                Label("Export photo…", systemImage: "square.and.arrow.up")
            }
            .disabled(model.selectedImage == nil || model.isExporting)

            Spacer()

            if model.isRenderingPreview {
                ProgressView()
                    .controlSize(.small)
                    .accessibilityLabel("Updating preview")
            }

            if !model.exportStatus.isEmpty {
                Text(model.exportStatus)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Text(model.selectedImageName)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func exportPhoto() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.jpeg]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = model.selectedImageName.replacingOccurrences(
            of: ".[^.]+$",
            with: "-edited.jpg",
            options: .regularExpression
        )
        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }
        Task {
            await model.exportPhoto(to: url)
        }
    }
}

private struct ImagePreviewView: View {
    let image: NSImage?
    let imageName: String
    let comparison: BeforeAfterComparison?

    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)

            if let comparison {
                BeforeAfterPreviewView(comparison: comparison)
                    .padding(24)
            } else if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding(24)
                    .accessibilityLabel(imageName)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: 44))
                        .foregroundStyle(.secondary)
                    Text("Open a photo to begin.")
                        .font(.headline)
                }
            }
        }
    }
}

private struct BeforeAfterPreviewView: View {
    let comparison: BeforeAfterComparison

    var body: some View {
        HStack(spacing: 18) {
            ComparisonPane(title: "Before", imageFile: comparison.before)
            ComparisonPane(title: "After", imageFile: comparison.after)
        }
    }
}

private struct ComparisonPane: View {
    let title: String
    let imageFile: LoadedImageFile

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Text(imageFile.name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Image(nsImage: imageFile.image)
                .resizable()
                .scaledToFit()
                .accessibilityLabel("\(title): \(imageFile.name)")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct AdjustmentPanelView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Adjustments")
                        .font(.headline)
                    Text("Showing \(model.visibleAdjustmentControls.count) controls")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Menu {
                    Button("Main 10") {
                        model.showDefaultAdjustmentControls()
                    }
                    Button("All \(AdjustmentControl.allCases.count)") {
                        model.showAllAdjustmentControls()
                    }

                    Divider()

                    ForEach(AdjustmentControl.allCases) { control in
                        Toggle(
                            control.title,
                            isOn: Binding(
                                get: { model.visibleAdjustmentControlIDs.contains(control.rawValue) },
                                set: { model.setAdjustmentControl(control, isVisible: $0) }
                            )
                        )
                    }
                } label: {
                    Image(systemName: "slider.horizontal.3")
                }
                .menuStyle(.borderlessButton)
                .help("Choose visible controls")
            }

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    ForEach(model.visibleAdjustmentControls) { control in
                        SliderRow(
                            title: control.title,
                            value: binding(for: control),
                            range: control.range
                        )
                    }
                }
            }
        }
        .padding(18)
    }

    private func binding(for control: AdjustmentControl) -> Binding<Double> {
        Binding(
            get: {
                model.adjustments.value(for: control)
            },
            set: { value in
                model.setAdjustmentValue(value, for: control)
            }
        )
    }
}

private struct SliderRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                Spacer()
                Text(value, format: .number.precision(.fractionLength(2)))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline)
            Slider(value: $value, in: range)
        }
    }
}
