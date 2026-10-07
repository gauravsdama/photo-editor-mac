import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var window: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if ProcessInfo.processInfo.arguments.contains("--benchmark-launch") {
            fputs("PhotoEditorMac launch benchmark ready\n", stderr)
            NSApp.terminate(nil)
            return
        }
        NSApplication.shared.setActivationPolicy(.regular)

        let rootView = ContentView()
            .environmentObject(AppModel.shared)
            .frame(minWidth: 1120, minHeight: 720)
            .onAppear {
                AppModel.shared.refreshGPUStatus()
            }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1280, height: 820),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Photo Editor"
        window.delegate = self
        window.contentView = NSHostingView(rootView: rootView)
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
        self.window = window

        if ProcessInfo.processInfo.arguments.contains("--ui-smoke-test") {
            Task { @MainActor in
                let succeeded = await NativeUISmokeTest.run(window: window, model: AppModel.shared)
                fflush(stdout)
                fflush(stderr)
                exit(succeeded ? 0 : 1)
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        AppModel.shared.confirmDiscardEdits() ? .terminateNow : .terminateCancel
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard AppModel.shared.confirmDiscardEdits() else { return false }
        AppModel.shared.clearWorkspace()
        return true
    }
}
