import SwiftUI
import AppKit

@main
struct MoltyMeterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

/// Custom window that accepts keyboard input even when borderless
class KeyableWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var window: KeyableWindow!
    private let dataProvider = SessionDataProvider()

    private let windowSize = NSSize(width: 260, height: 340)

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        window = KeyableWindow(
            contentRect: NSRect(origin: .zero, size: windowSize),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .normal
        window.hasShadow = true
        window.isMovableByWindowBackground = true
        window.collectionBehavior = [.ignoresCycle]

        // Restore position or center
        window.setFrameAutosaveName("MoltyMeterWindow")
        if window.frame.origin == .zero {
            window.center()
        }

        // Container with rounded corners
        let containerView = NSView(frame: window.contentView!.bounds)
        containerView.autoresizingMask = [.width, .height]
        containerView.wantsLayer = true
        containerView.layer?.cornerRadius = 20
        containerView.layer?.masksToBounds = true
        containerView.layer?.backgroundColor = NSColor(white: 0.08, alpha: 0.95).cgColor

        // Visual effect blur
        let visualEffect = NSVisualEffectView(frame: containerView.bounds)
        visualEffect.autoresizingMask = [.width, .height]
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .active
        visualEffect.material = .sidebar
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = 20
        visualEffect.layer?.masksToBounds = true

        // SwiftUI content
        let hostingView = NSHostingView(rootView: MoltyView(data: dataProvider))
        hostingView.frame = visualEffect.bounds
        hostingView.autoresizingMask = [.width, .height]
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = .clear

        visualEffect.addSubview(hostingView)
        containerView.addSubview(visualEffect)
        window.contentView = containerView

        window.makeKeyAndOrderFront(nil)

        Task { @MainActor in
            dataProvider.startMonitoring()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        Task { @MainActor in
            dataProvider.stopMonitoring()
        }
    }
}
