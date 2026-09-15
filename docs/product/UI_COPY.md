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
| `photo.api.error` | Action API error | Could not open image at {path} | Explain failure | Couldn’t open that image. Check the file format and permissions. | inventory | `AppModel+ActionAPI.swift` | UI should not reveal full personal paths by default. |

## Coverage gaps

Unsupported-format recovery, memory-pressure recovery, unsaved changes, and destructive reset language do not yet have complete user-facing states. The opt-in loopback Action API still needs token authentication before it is suitable for general release.
