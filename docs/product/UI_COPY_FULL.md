# PhotoEditorMac UI text inventory

This file is an exact, source-extracted inventory of visible SwiftUI text, dynamic status text, adjustment labels, and first-party errors. Runtime messages supplied by macOS are system-owned and are not enumerated. This is a review record, not a writing prompt: preserve wording, punctuation, capitalization, and interpolation exactly unless the owner approves a specific change. Do not add promotional headings, eyebrows, AI signposting, or explanatory copy without an explicit product decision.

<!-- BEGIN EXTRACTED_UI_TEXTS -->
```json
[
  {
    "file": "AdjustmentState.swift",
    "line": 35,
    "literal": "\"Exposure\"",
    "value": "Exposure"
  },
  {
    "file": "AdjustmentState.swift",
    "line": 36,
    "literal": "\"Brightness\"",
    "value": "Brightness"
  },
  {
    "file": "AdjustmentState.swift",
    "line": 37,
    "literal": "\"Contrast\"",
    "value": "Contrast"
  },
  {
    "file": "AdjustmentState.swift",
    "line": 38,
    "literal": "\"Saturation\"",
    "value": "Saturation"
  },
  {
    "file": "AdjustmentState.swift",
    "line": 39,
    "literal": "\"Vibrance\"",
    "value": "Vibrance"
  },
  {
    "file": "AdjustmentState.swift",
    "line": 40,
    "literal": "\"Highlights\"",
    "value": "Highlights"
  },
  {
    "file": "AdjustmentState.swift",
    "line": 41,
    "literal": "\"Shadows\"",
    "value": "Shadows"
  },
  {
    "file": "AdjustmentState.swift",
    "line": 42,
    "literal": "\"Temperature\"",
    "value": "Temperature"
  },
  {
    "file": "AdjustmentState.swift",
    "line": 43,
    "literal": "\"Tint\"",
    "value": "Tint"
  },
  {
    "file": "AdjustmentState.swift",
    "line": 44,
    "literal": "\"Sharpness\"",
    "value": "Sharpness"
  },
  {
    "file": "AdjustmentState.swift",
    "line": 45,
    "literal": "\"Clarity\"",
    "value": "Clarity"
  },
  {
    "file": "AdjustmentState.swift",
    "line": 46,
    "literal": "\"Noise Reduction\"",
    "value": "Noise Reduction"
  },
  {
    "file": "AdjustmentState.swift",
    "line": 47,
    "literal": "\"Gamma\"",
    "value": "Gamma"
  },
  {
    "file": "AdjustmentState.swift",
    "line": 48,
    "literal": "\"Hue\"",
    "value": "Hue"
  },
  {
    "file": "AdjustmentState.swift",
    "line": 49,
    "literal": "\"Sepia\"",
    "value": "Sepia"
  },
  {
    "file": "AdjustmentState.swift",
    "line": 50,
    "literal": "\"Monochrome\"",
    "value": "Monochrome"
  },
  {
    "file": "AdjustmentState.swift",
    "line": 51,
    "literal": "\"Vignette\"",
    "value": "Vignette"
  },
  {
    "file": "AdjustmentState.swift",
    "line": 52,
    "literal": "\"Vignette Radius\"",
    "value": "Vignette Radius"
  },
  {
    "file": "AdjustmentState.swift",
    "line": 53,
    "literal": "\"Bloom\"",
    "value": "Bloom"
  },
  {
    "file": "AdjustmentState.swift",
    "line": 54,
    "literal": "\"Bloom Radius\"",
    "value": "Bloom Radius"
  },
  {
    "file": "AdjustmentState.swift",
    "line": 55,
    "literal": "\"Blur\"",
    "value": "Blur"
  },
  {
    "file": "AdjustmentState.swift",
    "line": 56,
    "literal": "\"Red Balance\"",
    "value": "Red Balance"
  },
  {
    "file": "AdjustmentState.swift",
    "line": 57,
    "literal": "\"Green Balance\"",
    "value": "Green Balance"
  },
  {
    "file": "AdjustmentState.swift",
    "line": 58,
    "literal": "\"Blue Balance\"",
    "value": "Blue Balance"
  },
  {
    "file": "AdjustmentState.swift",
    "line": 59,
    "literal": "\"Black Level\"",
    "value": "Black Level"
  },
  {
    "file": "AdjustmentState.swift",
    "line": 60,
    "literal": "\"White Level\"",
    "value": "White Level"
  },
  {
    "file": "AppDelegate.swift",
    "line": 29,
    "literal": "\"Photo Editor\"",
    "value": "Photo Editor"
  },
  {
    "file": "AppModel.swift",
    "line": 13,
    "literal": "\"No image selected\"",
    "value": "No image selected"
  },
  {
    "file": "AppModel.swift",
    "line": 20,
    "literal": "\"Automation API off\"",
    "value": "Automation API off"
  },
  {
    "file": "AppModel.swift",
    "line": 61,
    "literal": "\"Action API listening at \\(self.actionAPIBaseURL.absoluteString)\"",
    "value": "Action API listening at \\(self.actionAPIBaseURL.absoluteString)"
  },
  {
    "file": "AppModel.swift",
    "line": 62,
    "literal": "\"Action API started\"",
    "value": "Action API started"
  },
  {
    "file": "AppModel.swift",
    "line": 64,
    "literal": "\"Automation API off\"",
    "value": "Automation API off"
  },
  {
    "file": "AppModel.swift",
    "line": 93,
    "literal": "\"GPU status refreshed\"",
    "value": "GPU status refreshed"
  },
  {
    "file": "AppModel.swift",
    "line": 105,
    "literal": "\"Could not open \\(url.lastPathComponent)\"",
    "value": "Could not open \\(url.lastPathComponent)"
  },
  {
    "file": "AppModel.swift",
    "line": 113,
    "literal": "\"The RAW sensor data could not be decoded on this Mac.\"",
    "value": "The RAW sensor data could not be decoded on this Mac."
  },
  {
    "file": "AppModel.swift",
    "line": 114,
    "literal": "\"Image open failed\"",
    "value": "Image open failed"
  },
  {
    "file": "AppModel.swift",
    "line": 134,
    "literal": "\"Image opened\"",
    "value": "Image opened"
  },
  {
    "file": "AppModel.swift",
    "line": 134,
    "literal": "\"\\(loadedImage.name) • \\(Int(loadedImage.size.width))x\\(Int(loadedImage.size.height))\"",
    "value": "\\(loadedImage.name) • \\(Int(loadedImage.size.width))x\\(Int(loadedImage.size.height))"
  },
  {
    "file": "AppModel.swift",
    "line": 142,
    "literal": "\"The sidecar refers to a different original photograph.\"",
    "value": "The sidecar refers to a different original photograph."
  },
  {
    "file": "AppModel.swift",
    "line": 166,
    "literal": "\"Before/after failed\"",
    "value": "Before/after failed"
  },
  {
    "file": "AppModel.swift",
    "line": 166,
    "literal": "\"Could not load comparison images.\"",
    "value": "Could not load comparison images."
  },
  {
    "file": "AppModel.swift",
    "line": 173,
    "literal": "\"Before/after comparison\"",
    "value": "Before/after comparison"
  },
  {
    "file": "AppModel.swift",
    "line": 181,
    "literal": "\"Before/after shown\"",
    "value": "Before/after shown"
  },
  {
    "file": "AppModel.swift",
    "line": 181,
    "literal": "\"\\(before.name) -> \\(after.name)\"",
    "value": "\\(before.name) -> \\(after.name)"
  },
  {
    "file": "AppModel.swift",
    "line": 189,
    "literal": "\"No image selected\"",
    "value": "No image selected"
  },
  {
    "file": "AppModel.swift",
    "line": 201,
    "literal": "\"Workspace cleared\"",
    "value": "Workspace cleared"
  },
  {
    "file": "AppModel.swift",
    "line": 210,
    "literal": "\"Visible controls updated\"",
    "value": "Visible controls updated"
  },
  {
    "file": "AppModel.swift",
    "line": 210,
    "literal": "\"Main \\(visibleAdjustmentControlIDs.count)\"",
    "value": "Main \\(visibleAdjustmentControlIDs.count)"
  },
  {
    "file": "AppModel.swift",
    "line": 215,
    "literal": "\"Visible controls updated\"",
    "value": "Visible controls updated"
  },
  {
    "file": "AppModel.swift",
    "line": 215,
    "literal": "\"All \\(visibleAdjustmentControlIDs.count)\"",
    "value": "All \\(visibleAdjustmentControlIDs.count)"
  },
  {
    "file": "AppModel.swift",
    "line": 222,
    "literal": "\"Visible controls updated\"",
    "value": "Visible controls updated"
  },
  {
    "file": "AppModel.swift",
    "line": 222,
    "literal": "\"\\(visibleAdjustmentControlIDs.count) controls\"",
    "value": "\\(visibleAdjustmentControlIDs.count) controls"
  },
  {
    "file": "AppModel.swift",
    "line": 231,
    "literal": "\"Visible controls updated\"",
    "value": "Visible controls updated"
  },
  {
    "file": "AppModel.swift",
    "line": 231,
    "literal": "\"\\(visibleAdjustmentControlIDs.count) controls\"",
    "value": "\\(visibleAdjustmentControlIDs.count) controls"
  },
  {
    "file": "AppModel.swift",
    "line": 236,
    "literal": "\"Adjustments reset\"",
    "value": "Adjustments reset"
  },
  {
    "file": "AppModel.swift",
    "line": 259,
    "literal": "\"Adjustments updated\"",
    "value": "Adjustments updated"
  },
  {
    "file": "AppModel.swift",
    "line": 274,
    "literal": "\"Image exported\"",
    "value": "Image exported"
  },
  {
    "file": "AppModel.swift",
    "line": 280,
    "literal": "\"Exporting…\"",
    "value": "Exporting…"
  },
  {
    "file": "AppModel.swift",
    "line": 284,
    "literal": "\"Exported \\(outputURL.lastPathComponent)\"",
    "value": "Exported \\(outputURL.lastPathComponent)"
  },
  {
    "file": "AppModel.swift",
    "line": 312,
    "literal": "\"Saved edits for \\(source.lastPathComponent)\"",
    "value": "Saved edits for \\(source.lastPathComponent)"
  },
  {
    "file": "AppModel.swift",
    "line": 338,
    "literal": "\"Edits saved\"",
    "value": "Edits saved"
  },
  {
    "file": "AppModel.swift",
    "line": 344,
    "literal": "\"Discard unsaved edits?\"",
    "value": "Discard unsaved edits?"
  },
  {
    "file": "AppModel.swift",
    "line": 345,
    "literal": "\"Save your edits first if you want to continue editing this photograph later.\"",
    "value": "Save your edits first if you want to continue editing this photograph later."
  },
  {
    "file": "AppModel.swift",
    "line": 346,
    "literal": "\"Keep editing\"",
    "value": "Keep editing"
  },
  {
    "file": "AppModel.swift",
    "line": 347,
    "literal": "\"Discard edits\"",
    "value": "Discard edits"
  },
  {
    "file": "ContentView.swift",
    "line": 36,
    "literal": "\"Photo Editor\"",
    "value": "Photo Editor"
  },
  {
    "file": "ContentView.swift",
    "line": 38,
    "literal": "\"Local edits on your Mac\"",
    "value": "Local edits on your Mac"
  },
  {
    "file": "ContentView.swift",
    "line": 69,
    "literal": "\"Automation history\"",
    "value": "Automation history"
  },
  {
    "file": "ContentView.swift",
    "line": 76,
    "literal": "\"Clear command log\"",
    "value": "Clear command log"
  },
  {
    "file": "ContentView.swift",
    "line": 83,
    "literal": "\"No edits from automation yet.\"",
    "value": "No edits from automation yet."
  },
  {
    "file": "ContentView.swift",
    "line": 123,
    "literal": "\"Rendering device\"",
    "value": "Rendering device"
  },
  {
    "file": "ContentView.swift",
    "line": 126,
    "literal": "\"Check again\"",
    "value": "Check again"
  },
  {
    "file": "ContentView.swift",
    "line": 130,
    "literal": "\"cpu\"",
    "value": "cpu"
  },
  {
    "file": "ContentView.swift",
    "line": 130,
    "literal": "\"exclamationmark.triangle\"",
    "value": "exclamationmark.triangle"
  },
  {
    "file": "ContentView.swift",
    "line": 133,
    "literal": "\"Apple Silicon build\"",
    "value": "Apple Silicon build"
  },
  {
    "file": "ContentView.swift",
    "line": 134,
    "literal": "\"Unified memory\"",
    "value": "Unified memory"
  },
  {
    "file": "ContentView.swift",
    "line": 190,
    "literal": "\"Open photo…\"",
    "value": "Open photo…"
  },
  {
    "file": "ContentView.swift",
    "line": 196,
    "literal": "\"Reset\"",
    "value": "Reset"
  },
  {
    "file": "ContentView.swift",
    "line": 203,
    "literal": "\"Clear\"",
    "value": "Clear"
  },
  {
    "file": "ContentView.swift",
    "line": 207,
    "literal": "\"Save edits…\"",
    "value": "Save edits…"
  },
  {
    "file": "ContentView.swift",
    "line": 208,
    "literal": "\"Save project…\"",
    "value": "Save project…"
  },
  {
    "file": "ContentView.swift",
    "line": 210,
    "literal": "\"Save XMP sidecar…\"",
    "value": "Save XMP sidecar…"
  },
  {
    "file": "ContentView.swift",
    "line": 212,
    "literal": "\"Open edits…\"",
    "value": "Open edits…"
  },
  {
    "file": "ContentView.swift",
    "line": 219,
    "literal": "\"Export rendered image…\"",
    "value": "Export rendered image…"
  },
  {
    "file": "ContentView.swift",
    "line": 228,
    "literal": "\"Updating preview\"",
    "value": "Updating preview"
  },
  {
    "file": "ContentView.swift",
    "line": 238,
    "literal": "\"Original RAW + edits\"",
    "value": "Original RAW + edits"
  },
  {
    "file": "ContentView.swift",
    "line": 238,
    "literal": "\"Original photo + edits\"",
    "value": "Original photo + edits"
  },
  {
    "file": "ContentView.swift",
    "line": 239,
    "literal": "\"Unsaved edits\"",
    "value": "Unsaved edits"
  },
  {
    "file": "ContentView.swift",
    "line": 239,
    "literal": "\"No saved edits\"",
    "value": "No saved edits"
  },
  {
    "file": "ContentView.swift",
    "line": 239,
    "literal": "\"Edits saved\"",
    "value": "Edits saved"
  },
  {
    "file": "ContentView.swift",
    "line": 245,
    "literal": "\"Export format\"",
    "value": "Export format"
  },
  {
    "file": "ContentView.swift",
    "line": 322,
    "literal": "\"Open a photo to begin.\"",
    "value": "Open a photo to begin."
  },
  {
    "file": "ContentView.swift",
    "line": 335,
    "literal": "\"Before\"",
    "value": "Before"
  },
  {
    "file": "ContentView.swift",
    "line": 336,
    "literal": "\"After\"",
    "value": "After"
  },
  {
    "file": "ContentView.swift",
    "line": 360,
    "literal": "\"\\(title): \\(imageFile.name)\"",
    "value": "\\(title): \\(imageFile.name)"
  },
  {
    "file": "ContentView.swift",
    "line": 373,
    "literal": "\"Adjustments\"",
    "value": "Adjustments"
  },
  {
    "file": "ContentView.swift",
    "line": 375,
    "literal": "\"Showing \\(model.visibleAdjustmentControls.count) controls\"",
    "value": "Showing \\(model.visibleAdjustmentControls.count) controls"
  },
  {
    "file": "ContentView.swift",
    "line": 383,
    "literal": "\"Main 10\"",
    "value": "Main 10"
  },
  {
    "file": "ContentView.swift",
    "line": 386,
    "literal": "\"All \\(AdjustmentControl.allCases.count)\"",
    "value": "All \\(AdjustmentControl.allCases.count)"
  },
  {
    "file": "ContentView.swift",
    "line": 405,
    "literal": "\"Choose visible controls\"",
    "value": "Choose visible controls"
  },
  {
    "file": "GPUStatus.swift",
    "line": 14,
    "literal": "\"Not checked\"",
    "value": "Not checked"
  },
  {
    "file": "GPUStatus.swift",
    "line": 20,
    "literal": "\"Metal/Core Image pending device detection\"",
    "value": "Metal/Core Image pending device detection"
  },
  {
    "file": "GPUStatus.swift",
    "line": 38,
    "literal": "\"No Metal device\"",
    "value": "No Metal device"
  },
  {
    "file": "GPUStatus.swift",
    "line": 44,
    "literal": "\"Unavailable\"",
    "value": "Unavailable"
  },
  {
    "file": "GPUStatus.swift",
    "line": 55,
    "literal": "\"Metal device + CIContext(mtlDevice:)\"",
    "value": "Metal device + CIContext(mtlDevice:)"
  },
  {
    "file": "ImageExporter.swift",
    "line": 16,
    "literal": "\"No image is loaded.\"",
    "value": "No image is loaded."
  },
  {
    "file": "ImageExporter.swift",
    "line": 18,
    "literal": "\"Could not create a Core Image input image from \\(path).\"",
    "value": "Could not create a Core Image input image from \\(path)."
  },
  {
    "file": "ImageExporter.swift",
    "line": 20,
    "literal": "\"Could not render the adjusted image.\"",
    "value": "Could not render the adjusted image."
  },
  {
    "file": "ImageExporter.swift",
    "line": 125,
    "literal": "\"The filename extension does not match the export format.\"",
    "value": "The filename extension does not match the export format."
  },
  {
    "file": "NativeUISmokeTest.swift",
    "line": 60,
    "literal": "\"Exported \\(output.lastPathComponent)\"",
    "value": "Exported \\(output.lastPathComponent)"
  },
  {
    "file": "PhaseOnePhotoEditorApp.swift",
    "line": 18,
    "literal": "\"Open Photo…\"",
    "value": "Open Photo…"
  },
  {
    "file": "PhotoProject.swift",
    "line": 14,
    "literal": "\"This edit document uses an unsupported version.\"",
    "value": "This edit document uses an unsupported version."
  },
  {
    "file": "PhotoProject.swift",
    "line": 17,
    "literal": "\"The edit document has an invalid original-image reference.\"",
    "value": "The edit document has an invalid original-image reference."
  },
  {
    "file": "PhotoProject.swift",
    "line": 21,
    "literal": "\"The edit document contains an invalid adjustment.\"",
    "value": "The edit document contains an invalid adjustment."
  },
  {
    "file": "PhotoProject.swift",
    "line": 50,
    "literal": "\"Edits must be saved separately from the original photograph.\"",
    "value": "Edits must be saved separately from the original photograph."
  },
  {
    "file": "PhotoProject.swift",
    "line": 52,
    "literal": "\"Choose a .photoedit project or an .xmp sidecar.\"",
    "value": "Choose a .photoedit project or an .xmp sidecar."
  },
  {
    "file": "PhotoProject.swift",
    "line": 69,
    "literal": "\"The sidecar does not contain a valid XMP RDF document.\"",
    "value": "The sidecar does not contain a valid XMP RDF document."
  },
  {
    "file": "PhotoProject.swift",
    "line": 91,
    "literal": "\"This XMP sidecar does not contain Photo Editor adjustments.\"",
    "value": "This XMP sidecar does not contain Photo Editor adjustments."
  },
  {
    "file": "PhotoProject.swift",
    "line": 99,
    "literal": "\"The original photograph has changed since these edits were saved.\"",
    "value": "The original photograph has changed since these edits were saved."
  },
  {
    "file": "PhotoProject.swift",
    "line": 108,
    "literal": "\"The edit document is too large.\"",
    "value": "The edit document is too large."
  },
  {
    "file": "PhotoSource.swift",
    "line": 21,
    "literal": "\"The file does not contain a recognized RAW image.\"",
    "value": "The file does not contain a recognized RAW image."
  },
  {
    "file": "PhotoSource.swift",
    "line": 25,
    "literal": "\"This RAW file is not supported by the RAW decoder on this Mac.\"",
    "value": "This RAW file is not supported by the RAW decoder on this Mac."
  },
  {
    "file": "PhotoSource.swift",
    "line": 35,
    "literal": "\"The RAW sensor data could not be decoded.\"",
    "value": "The RAW sensor data could not be decoded."
  },
  {
    "file": "PhotoSource.swift",
    "line": 45,
    "literal": "\"The image has invalid dimensions.\"",
    "value": "The image has invalid dimensions."
  },
  {
    "file": "PhotoSource.swift",
    "line": 90,
    "literal": "\"TIFF · 32-bit float · maximum precision\"",
    "value": "TIFF · 32-bit float · maximum precision"
  },
  {
    "file": "PhotoSource.swift",
    "line": 91,
    "literal": "\"TIFF · 16-bit · lossless\"",
    "value": "TIFF · 16-bit · lossless"
  },
  {
    "file": "PhotoSource.swift",
    "line": 92,
    "literal": "\"JPEG · maximum quality\"",
    "value": "JPEG · maximum quality"
  },
  {
    "file": "PhotoSource.swift",
    "line": 101,
    "literal": "\"Choose a TIFF or JPEG destination.\"",
    "value": "Choose a TIFF or JPEG destination."
  }
]
```
<!-- END EXTRACTED_UI_TEXTS -->
