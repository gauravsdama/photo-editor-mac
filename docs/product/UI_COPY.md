# PhotoEditorMac UI copy inventory

Human editorial source of truth for the first-party Phase 1 macOS app. The surrounding OmniGen, RapidRAW, and TUI Image Editor repos are upstream references and are not copy sources for this product.

| ID | Screen / state | Current text | Purpose / user intent | Proposed human rewrite | Status | Implementation location | Notes |
|---|---|---|---|---|---|---|---|
| `photo.app.open` | File menu / empty editor | Open Photo… / Open photo… / Open a photo to begin. | Start editing | Keep | approved | `PhaseOnePhotoEditorApp.swift`, `ContentView.swift` | Uses the photographer's object, not an implementation term. |
| `photo.app.title` | Window and sidebar | Photo Editor / Local edits on your Mac | Identify the app and local workflow | Keep | approved | `AppDelegate.swift`, `ContentView.swift` | No phase or scaffold language. |
| `photo.app.adjustments` | Inspector | Adjustments / Showing {visible} controls | Organize editing controls | Keep | approved | `ContentView.swift` | Preview updates after slider changes. |
| `photo.app.compare` | Comparison | Before / After | Compare source and result | Keep | inventory | `ContentView.swift` | Ensure image accessibility labels describe both state and filename. |
| `photo.app.gpu` | Diagnostics | Rendering device / Check again | Diagnose rendering device | Keep | approved | `ContentView.swift`, `GPUStatus.swift` | Secondary sidebar information. |
| `photo.app.command-log` | Sidebar | Automation history / No edits from automation yet. | Show automation history | Keep | approved | `ContentView.swift` | Does not advertise AI or imply waiting. |
| `photo.app.export` | Toolbar / export state | Export photo… / Exporting… / Exported {filename} | Save an edited copy | Keep | approved | `ContentView.swift`, `AppModel.swift` | Native save panel supplies destination and cancellation. |
| `photo.api.error` | Action API error | Could not open image. | Explain failure | Couldn’t open that image. Check the file format and permissions. | inventory | `AppModel+ActionAPI.swift` | API responses do not reveal full personal paths. |

## Coverage gaps

Owner-requested RAW workflow copy: Open edits…; Save edits…; Save XMP sidecar…; Export rendered image…; Export format; TIFF · 32-bit float · maximum precision; TIFF · 16-bit · lossless; JPEG · maximum quality; Original RAW + edits; Original photo + edits; Unsaved edits; Edits saved; Saved edits for {filename}; Edits could not be opened; Edits could not be saved. These distinguish original-preserving edit persistence from rendered output.

Additional persistence/recovery copy: Save project…; No saved edits; Discard unsaved edits?; Save your edits first if you want to continue editing this photograph later.; Keep editing; Discard edits; The RAW sensor data could not be decoded on this Mac. First-party document validation errors are enumerated in the full extracted inventory.

Unsupported-format recovery, memory-pressure recovery, unsaved changes, and destructive reset language do not yet have complete user-facing states. The opt-in loopback Action API requires a per-launch bearer token for non-health requests.
