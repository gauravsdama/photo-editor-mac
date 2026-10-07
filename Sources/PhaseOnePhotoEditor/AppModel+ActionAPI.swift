import Foundation

extension AppModel {
    func handleActionAPIRequest(_ request: ActionAPIRequest) async -> ActionAPIResponse {
        switch (request.method, request.path) {
        case ("GET", "/health"):
            return .json(healthPayload())
        case ("GET", "/api/actions"):
            return .json(["ok": true, "actions": .objects(ActionCatalog.descriptors.map(\.apiRepresentation))])
        case ("GET", "/api/state"):
            return .json(["ok": true, "state": .object(statePayload())])
        case ("POST", "/api/action"):
            return await dispatchGenericAction(request.body)
        default:
            guard let descriptor = ActionCatalog.descriptor(method: request.method, path: request.path) else {
                return .error(
                    statusCode: 404,
                    message: "Unknown action API route: \(request.method) \(request.path)",
                    suggestion: "Call GET /api/actions to discover supported actions."
                )
            }
            return await performAction(descriptor.action, parameters: request.body)
        }
    }

    private func dispatchGenericAction(_ body: JSONObject) async -> ActionAPIResponse {
        guard let action = body["action"]?.stringValue else {
            return .error(statusCode: 400, message: "Missing required string field: action")
        }

        guard let descriptor = ActionCatalog.descriptor(named: action) else {
            return .error(
                statusCode: 404,
                message: "Unknown action: \(action)",
                suggestion: "Call GET /api/actions to discover supported action names."
            )
        }
        let parameters: JSONObject
        if let rawParameters = body["parameters"] {
            guard let object = rawParameters.objectValue else {
                return .error(statusCode: 400, message: "Field must be an object: parameters")
            }
            parameters = object
        } else {
            parameters = [:]
        }
        return await performAction(descriptor.action, parameters: parameters)
    }

    private func performAction(
        _ action: PhotoEditorAction,
        parameters: JSONObject
    ) async -> ActionAPIResponse {
        switch action {
        case .listControls:
            return .json(controlsPayload())
        case .refreshGPU:
            refreshGPUStatus()
            return .json(["ok": true, "state": .object(statePayload())])
        case .openImage:
            return await openImageAction(parameters)
        case .clearWorkspace:
            clearWorkspace()
            return .json(["ok": true, "state": .object(statePayload())])
        case .clearCommandLog:
            clearCommandLog()
            return .json(["ok": true, "state": .object(statePayload())])
        case .showBeforeAfter:
            return await showBeforeAfterAction(parameters)
        case .setVisibleControls:
            return setVisibleControlsAction(parameters)
        case .setAdjustments:
            return setAdjustmentsAction(parameters)
        case .resetAdjustments:
            resetAdjustments()
            return .json(["ok": true, "adjustments": .object(adjustments.apiRepresentation.mapValues(JSONValue.number))])
        case .exportImage:
            return await exportImageAction(parameters)
        case .saveEdits:
            guard let path = parameters["outputPath"]?.stringValue, !path.isEmpty else {
                return .error(statusCode: 400, message: "Missing required string field: outputPath")
            }
            do {
                try await saveEdits(to: URL(fileURLWithPath: path))
                return .json(["ok": true])
            } catch { return .error(statusCode: 400, message: "Could not save edits.") }
        case .openEdits:
            guard let path = parameters["path"]?.stringValue, !path.isEmpty else {
                return .error(statusCode: 400, message: "Missing required string field: path")
            }
            return await openEdits(from: URL(fileURLWithPath: path))
                ? .json(["ok": true, "state": .object(statePayload())])
                : .error(statusCode: 400, message: "Could not open edits.")
        }
    }

    private func openImageAction(_ body: JSONObject) async -> ActionAPIResponse {
        guard let path = body["path"]?.stringValue, !path.isEmpty else {
            return .error(statusCode: 400, message: "Missing required string field: path")
        }

        let didLoad = await loadImage(from: URL(fileURLWithPath: path))
        guard didLoad else {
            return .error(
                statusCode: 400,
                message: "Could not open image.",
                suggestion: "Use an absolute path to a readable image file."
            )
        }

        return .json(["ok": true, "state": .object(statePayload())])
    }

    private func showBeforeAfterAction(_ body: JSONObject) async -> ActionAPIResponse {
        guard let beforePath = body["beforePath"]?.stringValue, !beforePath.isEmpty else {
            return .error(statusCode: 400, message: "Missing required string field: beforePath")
        }
        guard let afterPath = body["afterPath"]?.stringValue, !afterPath.isEmpty else {
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

        return .json(["ok": true, "state": .object(statePayload())])
    }

    private func setVisibleControlsAction(_ body: JSONObject) -> ActionAPIResponse {
        if let preset = body["preset"]?.stringValue {
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
            guard let controls = body["controls"]?.stringArrayValue, !controls.isEmpty else {
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
            "visibleControls": .strings(visibleAdjustmentControls.map(\.rawValue)),
            "visibleControlCount": .number(Double(visibleAdjustmentControls.count)),
            "controlCount": .number(Double(AdjustmentControl.allCases.count))
        ])
    }

    private func exportImageAction(_ body: JSONObject) async -> ActionAPIResponse {
        guard let outputPath = body["outputPath"]?.stringValue, !outputPath.isEmpty else {
            return .error(
                statusCode: 400,
                message: "Missing required string field: outputPath",
                suggestion: "Choose an explicit writable TIFF or JPEG destination."
            )
        }
        let quality: Double
        if let rawQuality = body["quality"] {
            guard let value = rawQuality.numberValue,
                  value.isFinite,
                  (0.1...1.0).contains(value) else {
                return .error(statusCode: 400, message: "Field must be a number from 0.1 through 1.0: quality")
            }
            quality = value
        } else {
            quality = ImageExporter.maximumJPEGQuality
        }

        let format: RenderedExportFormat?
        if let value = body["format"] {
            guard let name = value.stringValue, let parsed = RenderedExportFormat(rawValue: name) else {
                return .error(statusCode: 400, message: "Choose tiffFloat32, tiff16, or jpeg as the export format.")
            }
            format = parsed
        } else { format = nil }

        do {
            let result = try await exportAdjustedImage(
                to: URL(fileURLWithPath: outputPath),
                quality: quality,
                format: format
            )
            return .json(["ok": true, "export": .object(result.apiRepresentation)])
        } catch {
            return .error(
                statusCode: 400,
                message: "Could not export image.",
                suggestion: "Load an image, set adjustments, then export to an absolute writable output path."
            )
        }
    }

    private func healthPayload() -> JSONObject {
        return [
            "ok": true,
            "service": "PhotoEditorMac Action API",
            "baseURL": .string(actionAPIBaseURL.absoluteString),
            "authentication": "Bearer token required for non-health requests",
            "state": .object(statePayload())
        ]
    }

    private func setAdjustmentsAction(_ body: JSONObject) -> ActionAPIResponse {
        for (name, value) in body {
            guard let control = AdjustmentControl(rawValue: name) else {
                return .error(statusCode: 400, message: "Unknown adjustment field: \(name)")
            }
            guard let number = value.numberValue, number.isFinite else {
                return .error(statusCode: 400, message: "Field must be a finite number: \(name)")
            }
            guard control.range.contains(number) else {
                return .error(
                    statusCode: 400,
                    message: "Adjustment is outside its supported range: \(name)"
                )
            }
        }
        setAdjustments(apiValues: body)
        return .json([
            "ok": true,
            "adjustments": .object(adjustments.apiRepresentation.mapValues(JSONValue.number))
        ])
    }

    private func statePayload() -> JSONObject {
        var selectedImagePayload: JSONObject = [
            "isLoaded": .bool(selectedImage != nil),
            "name": .string(selectedImageName)
        ]
        selectedImagePayload["isRAW"] = .bool(isRAWSource)
        if let selectedImageSize {
            selectedImagePayload["width"] = .number(Double(selectedImageSize.width))
            selectedImagePayload["height"] = .number(Double(selectedImageSize.height))
        }

        var state: JSONObject = [
            "api": .object([
                "baseURL": .string(actionAPIBaseURL.absoluteString),
                "status": .string(actionAPIStatus)
            ]),
            "gpuStatus": .object(gpuStatus.apiRepresentation),
            "selectedImage": .object(selectedImagePayload),
            "previewMode": .string(beforeAfterComparison == nil ? "single" : "beforeAfter"),
            "adjustmentControlCount": .number(Double(AdjustmentControl.allCases.count)),
            "defaultVisibleAdjustmentControls": .strings(Array(AdjustmentControl.defaultVisibleIDs).sorted()),
            "visibleAdjustmentControls": .strings(visibleAdjustmentControls.map(\.rawValue)),
            "visibleAdjustmentControlCount": .number(Double(visibleAdjustmentControls.count)),
            "adjustments": .object(adjustments.apiRepresentation.mapValues(JSONValue.number)),
            "edits": .object(["hasUnsavedEdits": .bool(hasUnsavedEdits), "hasSavedDocument": .bool(projectURL != nil)]),
            "exportFormat": .string(exportFormat.rawValue),
            "commandLog": .objects(commandLog.map(\.apiRepresentation))
        ]
        if let beforeAfterComparison {
            state["comparison"] = .object(beforeAfterComparison.apiRepresentation)
        }
        return state
    }

    private func controlsPayload() -> JSONObject {
        [
            "ok": true,
            "controlCount": .number(Double(AdjustmentControl.allCases.count)),
            "defaultVisibleControlCount": .number(Double(AdjustmentControl.defaultVisibleIDs.count)),
            "visibleControlCount": .number(Double(visibleAdjustmentControls.count)),
            "defaultVisibleControls": .strings(Array(AdjustmentControl.defaultVisibleIDs).sorted()),
            "visibleControls": .strings(visibleAdjustmentControls.map(\.rawValue)),
            "controls": .objects(AdjustmentControl.apiCatalog)
        ]
    }

}
