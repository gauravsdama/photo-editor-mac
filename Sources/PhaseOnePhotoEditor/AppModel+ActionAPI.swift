import Foundation

extension AppModel {
    func handleActionAPIRequest(_ request: ActionAPIRequest) async -> ActionAPIResponse {
        switch (request.method, request.path) {
        case ("GET", "/health"):
            return .json(healthPayload())
        case ("GET", "/api/actions"):
            return .json(["ok": true, "actions": actionCatalog()])
        case ("GET", "/api/state"):
            return .json(["ok": true, "state": statePayload()])
        case ("GET", "/api/controls"):
            return .json(controlsPayload())
        case ("POST", "/api/action"):
            return await dispatchGenericAction(request.body)
        case ("POST", "/api/gpu/refresh"):
            refreshGPUStatus()
            return .json(["ok": true, "state": statePayload()])
        case ("POST", "/api/image/open"):
            return await openImageAction(request.body)
        case ("POST", "/api/workspace/clear"):
            clearWorkspace()
            return .json(["ok": true, "state": statePayload()])
        case ("POST", "/api/commands/clear"):
            clearCommandLog()
            return .json(["ok": true, "state": statePayload()])
        case ("POST", "/api/compare/before-after"):
            return await showBeforeAfterAction(request.body)
        case ("POST", "/api/controls/visible"):
            return setVisibleControlsAction(request.body)
        case ("POST", "/api/adjustments/set"):
            setAdjustments(apiValues: request.body)
            return .json(["ok": true, "adjustments": adjustments.apiRepresentation])
        case ("POST", "/api/adjustments/reset"):
            resetAdjustments()
            return .json(["ok": true, "adjustments": adjustments.apiRepresentation])
        case ("POST", "/api/image/export"):
            return await exportImageAction(request.body)
        case ("POST", "/api/omnigen/command-preview"):
            return omniGenCommandPreviewAction(request.body)
        default:
            return .error(
                statusCode: 404,
                message: "Unknown action API route: \(request.method) \(request.path)",
                suggestion: "Call GET /api/actions to discover supported actions."
            )
        }
    }

    private func dispatchGenericAction(_ body: [String: Any]) async -> ActionAPIResponse {
        guard let action = body["action"] as? String else {
            return .error(statusCode: 400, message: "Missing required string field: action")
        }

        let parameters = body["parameters"] as? [String: Any] ?? [:]
        switch action {
        case "list_controls":
            return .json(controlsPayload())
        case "refresh_gpu":
            refreshGPUStatus()
            return .json(["ok": true, "state": statePayload()])
        case "open_image":
            return await openImageAction(parameters)
        case "clear_workspace":
            clearWorkspace()
            return .json(["ok": true, "state": statePayload()])
        case "clear_command_log":
            clearCommandLog()
            return .json(["ok": true, "state": statePayload()])
        case "show_before_after":
            return await showBeforeAfterAction(parameters)
        case "set_visible_controls":
            return setVisibleControlsAction(parameters)
        case "set_adjustments":
            setAdjustments(apiValues: parameters)
            return .json(["ok": true, "adjustments": adjustments.apiRepresentation])
        case "reset_adjustments":
            resetAdjustments()
            return .json(["ok": true, "adjustments": adjustments.apiRepresentation])
        case "export_image":
            return await exportImageAction(parameters)
        case "preview_omnigen_command":
            return omniGenCommandPreviewAction(parameters)
        default:
            return .error(
                statusCode: 404,
                message: "Unknown action: \(action)",
                suggestion: "Call GET /api/actions to discover supported action names."
            )
        }
    }

    private func openImageAction(_ body: [String: Any]) async -> ActionAPIResponse {
        guard let path = body["path"] as? String, !path.isEmpty else {
            return .error(statusCode: 400, message: "Missing required string field: path")
        }

        let didLoad = await loadImage(from: URL(fileURLWithPath: path))
        guard didLoad else {
            return .error(
                statusCode: 400,
                message: "Could not open image at \(path)",
                suggestion: "Use an absolute path to a readable image file."
            )
        }

        return .json(["ok": true, "state": statePayload()])
    }

    private func showBeforeAfterAction(_ body: [String: Any]) async -> ActionAPIResponse {
        guard let beforePath = body["beforePath"] as? String, !beforePath.isEmpty else {
            return .error(statusCode: 400, message: "Missing required string field: beforePath")
        }
        guard let afterPath = body["afterPath"] as? String, !afterPath.isEmpty else {
            return .error(statusCode: 400, message: "Missing required string field: afterPath")
        }

        let didLoad = await showBeforeAfter(
            before: URL(fileURLWithPath: beforePath),
            after: URL(fileURLWithPath: afterPath)
        )
        guard didLoad else {
            return .error(
                statusCode: 400,
                message: "Could not open before/after images.",
                suggestion: "Use absolute paths to readable image files."
            )
        }

        return .json(["ok": true, "state": statePayload()])
    }

    private func setVisibleControlsAction(_ body: [String: Any]) -> ActionAPIResponse {
        if let preset = body["preset"] as? String {
            switch preset {
            case "main", "default":
                showDefaultAdjustmentControls()
            case "all":
                showAllAdjustmentControls()
            default:
                return .error(
                    statusCode: 400,
                    message: "Unknown visible controls preset: \(preset)",
                    suggestion: "Use preset main, default, all, or provide a controls array."
                )
            }
        } else {
            let controls = stringArray(from: body["controls"])
            guard !controls.isEmpty else {
                return .error(
                    statusCode: 400,
                    message: "Missing controls array or preset.",
                    suggestion: "Provide controls: [\"exposure\", \"contrast\"] or preset: \"main\"."
                )
            }
            setVisibleAdjustmentControls(controls)
        }

        return .json([
            "ok": true,
            "visibleControls": visibleAdjustmentControls.map(\.rawValue),
            "visibleControlCount": visibleAdjustmentControls.count,
            "controlCount": AdjustmentControl.allCases.count
        ])
    }

    private func omniGenCommandPreviewAction(_ body: [String: Any]) -> ActionAPIResponse {
        guard let prompt = body["prompt"] as? String, !prompt.isEmpty else {
            return .error(statusCode: 400, message: "Missing required string field: prompt")
        }

        let inputImagePath = body["inputImagePath"] as? String
        let outputImagePath = body["outputImagePath"] as? String
            ?? "/tmp/phase-one-omnigen-output.png"

        guard let command = omniGen.commandPreview(
            prompt: prompt,
            inputImage: inputImagePath.map(URL.init(fileURLWithPath:)),
            outputImage: URL(fileURLWithPath: outputImagePath)
        ) else {
            return .error(
                statusCode: 503,
                message: "OmniGen command preview is not configured.",
                suggestion: "Set PHOTO_EDITOR_PHASE_ROOT to a local phase1 checkout before launching the app."
            )
        }
        recordCommand("OmniGen command previewed", detail: prompt)

        return .json([
            "ok": true,
            "command": command,
            "environment": omniGen.mpsEnvironment,
            "note": "Preview only. Model execution is intentionally separate until the OmniGen Python environment is installed."
        ])
    }

    private func exportImageAction(_ body: [String: Any]) async -> ActionAPIResponse {
        guard let outputPath = body["outputPath"] as? String, !outputPath.isEmpty else {
            return .error(
                statusCode: 400,
                message: "Missing required string field: outputPath",
                suggestion: "Choose an explicit writable JPEG destination."
            )
        }
        let quality = body["quality"] as? Double ?? 0.94

        do {
            let result = try await exportAdjustedImage(
                to: URL(fileURLWithPath: outputPath),
                quality: quality
            )
            return .json(["ok": true, "export": result.apiRepresentation])
        } catch {
            return .error(
                statusCode: 400,
                message: error.localizedDescription,
                suggestion: "Load an image, set adjustments, then export to an absolute writable output path."
            )
        }
    }

    private func healthPayload() -> [String: Any] {
        return [
            "ok": true,
            "service": "PhotoEditorMac Action API",
            "baseURL": actionAPIBaseURL.absoluteString,
            "state": statePayload()
        ]
    }

    private func statePayload() -> [String: Any] {
        var selectedImagePayload: [String: Any] = [
            "isLoaded": selectedImage != nil,
            "name": selectedImageName
        ]
        if let selectedImagePath {
            selectedImagePayload["path"] = selectedImagePath
        }
        if let selectedImageSize {
            selectedImagePayload["width"] = selectedImageSize.width
            selectedImagePayload["height"] = selectedImageSize.height
        }

        var state: [String: Any] = [
            "api": [
                "baseURL": actionAPIBaseURL.absoluteString,
                "status": actionAPIStatus
            ],
            "gpuStatus": gpuStatus.apiRepresentation,
            "selectedImage": selectedImagePayload,
            "previewMode": beforeAfterComparison == nil ? "single" : "beforeAfter",
            "adjustmentControlCount": AdjustmentControl.allCases.count,
            "defaultVisibleAdjustmentControls": Array(AdjustmentControl.defaultVisibleIDs).sorted(),
            "visibleAdjustmentControls": visibleAdjustmentControls.map(\.rawValue),
            "visibleAdjustmentControlCount": visibleAdjustmentControls.count,
            "adjustments": adjustments.apiRepresentation,
            "commandLog": commandLog.map(\.apiRepresentation)
        ]
        if let beforeAfterComparison {
            state["comparison"] = beforeAfterComparison.apiRepresentation
        }
        return state
    }

    private func controlsPayload() -> [String: Any] {
        [
            "ok": true,
            "controlCount": AdjustmentControl.allCases.count,
            "defaultVisibleControlCount": AdjustmentControl.defaultVisibleIDs.count,
            "visibleControlCount": visibleAdjustmentControls.count,
            "defaultVisibleControls": Array(AdjustmentControl.defaultVisibleIDs).sorted(),
            "visibleControls": visibleAdjustmentControls.map(\.rawValue),
            "controls": AdjustmentControl.apiCatalog
        ]
    }

    private func actionCatalog() -> [[String: Any]] {
        [
            [
                "name": "list_controls",
                "method": "GET",
                "path": "/api/controls",
                "description": "List every photo adjustment control, including range, default value, and default visibility.",
                "parameters": []
            ],
            [
                "name": "refresh_gpu",
                "method": "POST",
                "path": "/api/gpu/refresh",
                "description": "Refresh Metal GPU detection and Apple Silicon readiness status.",
                "parameters": []
            ],
            [
                "name": "open_image",
                "method": "POST",
                "path": "/api/image/open",
                "description": "Open an image file in the editor preview.",
                "parameters": [["name": "path", "type": "string", "required": true]]
            ],
            [
                "name": "clear_workspace",
                "method": "POST",
                "path": "/api/workspace/clear",
                "description": "Clear the loaded image, before/after comparison, and adjustment values.",
                "parameters": []
            ],
            [
                "name": "clear_command_log",
                "method": "POST",
                "path": "/api/commands/clear",
                "description": "Clear the visible AI command log.",
                "parameters": []
            ],
            [
                "name": "show_before_after",
                "method": "POST",
                "path": "/api/compare/before-after",
                "description": "Show a side-by-side before/after image comparison in the editor preview.",
                "parameters": [
                    ["name": "beforePath", "type": "string", "required": true],
                    ["name": "afterPath", "type": "string", "required": true]
                ]
            ],
            [
                "name": "set_visible_controls",
                "method": "POST",
                "path": "/api/controls/visible",
                "description": "Choose which adjustment controls are visible in the native UI.",
                "parameters": [
                    ["name": "preset", "type": "string", "required": false, "values": ["main", "default", "all"]],
                    ["name": "controls", "type": "array<string>", "required": false]
                ]
            ],
            [
                "name": "set_adjustments",
                "method": "POST",
                "path": "/api/adjustments/set",
                "description": "Set non-destructive adjustment values.",
                "parameters": AdjustmentControl.apiCatalog
            ],
            [
                "name": "reset_adjustments",
                "method": "POST",
                "path": "/api/adjustments/reset",
                "description": "Reset all adjustment values to defaults.",
                "parameters": []
            ],
            [
                "name": "export_image",
                "method": "POST",
                "path": "/api/image/export",
                "description": "Render the loaded image with current adjustments and write a JPEG file.",
                "parameters": [
                    ["name": "outputPath", "type": "string", "required": false],
                    ["name": "quality", "type": "number", "required": false, "range": [0.1, 1.0]]
                ]
            ],
            [
                "name": "preview_omnigen_command",
                "method": "POST",
                "path": "/api/omnigen/command-preview",
                "description": "Return the MPS-safe OmniGen sidecar command for a prompt/image edit job.",
                "parameters": [
                    ["name": "prompt", "type": "string", "required": true],
                    ["name": "inputImagePath", "type": "string", "required": false],
                    ["name": "outputImagePath", "type": "string", "required": false]
                ]
            ]
        ]
    }

    private func stringArray(from rawValue: Any?) -> [String] {
        if let values = rawValue as? [String] {
            return values
        }
        if let values = rawValue as? [Any] {
            return values.compactMap { $0 as? String }
        }
        return []
    }
}
