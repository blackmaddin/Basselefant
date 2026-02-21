import AppKit
import SwiftUI

@MainActor
final class ExternalDisplayCoordinator {
    private var window: NSWindow?

    func present(on screen: NSScreen, model: AppModel) {
        if window == nil {
            let window = NSWindow(
                contentRect: screen.frame,
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.title = "Basselefant Live Output"
            window.isOpaque = true
            window.backgroundColor = .black
            self.window = window
        }

        guard let window else { return }
        window.setFrame(screen.frame, display: true)
        window.contentViewController = NSHostingController(
            rootView: ExternalDisplayView()
                .environmentObject(model)
        )
        window.makeKeyAndOrderFront(nil)
    }

    func dismiss() {
        window?.orderOut(nil)
        window?.close()
        window = nil
    }
}
