import Foundation

enum PhotoEditorAction: String, Sendable {
    case listControls = "list_controls"
    case refreshGPU = "refresh_gpu"
    case openImage = "open_image"
    case clearWorkspace = "clear_workspace"
    case clearCommandLog = "clear_command_log"
    case showBeforeAfter = "show_before_after"
    case setVisibleControls = "set_visible_controls"
    case setAdjustments = "set_adjustments"
    case resetAdjustments = "reset_adjustments"
    case exportImage = "export_image"
    case saveEdits = "save_edits"
    case openEdits = "open_edits"
}

struct ActionDescriptor: Sendable {
    let action: PhotoEditorAction
    let method: String
    let path: String
    let description: String
    let parameters: [JSONObject]

    var apiRepresentation: JSONObject {
        [
            "name": .string(action.rawValue),
            "method": .string(method),
            "path": .string(path),
            "description": .string(description),
            "parameters": .objects(parameters)
        ]
    }
}

enum ActionCatalog {
    static let descriptors: [ActionDescriptor] = [
        ActionDescriptor(
            action: .listControls,
            method: "GET",
            path: "/api/controls",
            description: "List every photo adjustment control, including range, default value, and default visibility.",
            parameters: []
        ),
        ActionDescriptor(
            action: .refreshGPU,
            method: "POST",
            path: "/api/gpu/refresh",
            description: "Refresh Metal GPU detection and Apple Silicon readiness status.",
            parameters: []
        ),
        ActionDescriptor(
            action: .openImage,
            method: "POST",
            path: "/api/image/open",
            description: "Open an image file in the editor preview.",
            parameters: [["name": "path", "type": "string", "required": true]]
        ),
        ActionDescriptor(
            action: .clearWorkspace,
            method: "POST",
            path: "/api/workspace/clear",
            description: "Clear the loaded image, before/after comparison, and adjustment values.",
            parameters: []
        ),
        ActionDescriptor(
            action: .clearCommandLog,
            method: "POST",
            path: "/api/commands/clear",
            description: "Clear the visible automation command log.",
            parameters: []
        ),
        ActionDescriptor(
            action: .showBeforeAfter,
            method: "POST",
            path: "/api/compare/before-after",
            description: "Show a side-by-side before/after image comparison in the editor preview.",
            parameters: [
                ["name": "beforePath", "type": "string", "required": true],
                ["name": "afterPath", "type": "string", "required": true]
            ]
        ),
        ActionDescriptor(
            action: .setVisibleControls,
            method: "POST",
            path: "/api/controls/visible",
            description: "Choose which adjustment controls are visible in the native UI.",
            parameters: [
                ["name": "preset", "type": "string", "required": false, "values": ["main", "default", "all"]],
                ["name": "controls", "type": "array<string>", "required": false]
            ]
        ),
        ActionDescriptor(
            action: .setAdjustments,
            method: "POST",
            path: "/api/adjustments/set",
            description: "Set non-destructive adjustment values.",
            parameters: AdjustmentControl.apiCatalog
        ),
        ActionDescriptor(
            action: .resetAdjustments,
            method: "POST",
            path: "/api/adjustments/reset",
            description: "Reset all adjustment values to defaults.",
            parameters: []
        ),
        ActionDescriptor(
            action: .exportImage,
            method: "POST",
            path: "/api/image/export",
            description: "Export a full-resolution rendered TIFF or JPEG. TIFF defaults to 32-bit floating point; JPEG quality defaults to 1.",
            parameters: [
                ["name": "outputPath", "type": "string", "required": true],
                ["name": "quality", "type": "number", "required": false, "range": [0.1, 1.0], "default": .number(ImageExporter.maximumJPEGQuality)],
                ["name": "format", "type": "string", "required": false, "values": ["tiffFloat32", "tiff16", "jpeg"]]
            ]
        ),
        ActionDescriptor(action: .saveEdits, method: "POST", path: "/api/edits/save",
            description: "Save a .photoedit project or XMP sidecar without changing the original.",
            parameters: [["name": "outputPath", "type": "string", "required": true]]),
        ActionDescriptor(action: .openEdits, method: "POST", path: "/api/edits/open",
            description: "Reopen the original photograph with its saved adjustments.",
            parameters: [["name": "path", "type": "string", "required": true]])
    ]

    static func descriptor(method: String, path: String) -> ActionDescriptor? {
        descriptors.first { $0.method == method && $0.path == path }
    }

    static func descriptor(named name: String) -> ActionDescriptor? {
        descriptors.first { $0.action.rawValue == name }
    }
}
