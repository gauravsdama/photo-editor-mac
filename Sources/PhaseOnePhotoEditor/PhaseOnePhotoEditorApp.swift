import AppKit
import SwiftUI

@main
struct PhaseOnePhotoEditorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        NSApplication.shared.setActivationPolicy(.regular)
    }

    var body: some Scene {
        Settings {
            EmptyView()
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open Photo…") {
                    AppModel.shared.isImportingImage = true
                }
                .keyboardShortcut("o")
            }
        }
    }
}
