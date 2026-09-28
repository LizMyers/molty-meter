import SwiftUI
import AppKit
import CoreGraphics

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

    private let windowSize = NSSize(width: 260, height: 370)

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
        // Reverted Sep 28: the desktop-icon layer only renders when nothing else covers
        // that screen region, so with any normal window over that spot the widget vanished
        // entirely — worse than the original "floats above" complaint. Back to .normal;
        // the orderFront-not-makeKey change below (which stops focus-stealing at launch)
        // stays, since that part was an unambiguous improvement.
        window.level = .normal
        window.hasShadow = false
        window.isMovableByWindowBackground = true
        window.collectionBehavior = [.ignoresCycle]

        // Restore position or center
        window.setFrameAutosaveName("MoltyMeterWindow")
        if window.frame.origin == .zero {
            window.center()
        }

        // Create a container view with rounded corners
        let containerView = NSView(frame: window.contentView!.bounds)
        containerView.autoresizingMask = [.width, .height]
        containerView.wantsLayer = true
        containerView.layer?.cornerRadius = 20
        containerView.layer?.masksToBounds = true
        containerView.layer?.opacity = 0.97  // Was 0.85 — less transparent per Liz's request

        // Visual effect view for background blur (like Apple widgets)
        let visualEffect = NSVisualEffectView(frame: containerView.bounds)
        visualEffect.autoresizingMask = [.width, .height]
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .active
        visualEffect.material = .hudWindow  // Was .menu — denser/darker blur material
        visualEffect.appearance = NSAppearance(named: .darkAqua)  // Force dark appearance
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = 20
        visualEffect.layer?.masksToBounds = true

        // Darkening overlay — was a white 0.2-alpha "lighten" layer; flipped to black
        // per Liz's request for a darker background.
        let lightenOverlay = NSView(frame: visualEffect.bounds)
        lightenOverlay.autoresizingMask = [.width, .height]
        lightenOverlay.wantsLayer = true
        lightenOverlay.layer?.backgroundColor = NSColor(white: 0.0, alpha: 0.35).cgColor
        visualEffect.addSubview(lightenOverlay)

        // SwiftUI content
        let hostingView = NSHostingView(rootView: MoltyView(data: dataProvider))
        hostingView.frame = visualEffect.bounds
        hostingView.autoresizingMask = [.width, .height]
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = .clear

        visualEffect.addSubview(hostingView)
        containerView.addSubview(visualEffect)
        window.contentView = containerView

        // orderFront (not makeKeyAndOrderFront) — a desktop widget shouldn't steal
        // keyboard focus from whatever app you're actually using when it launches.
        window.orderFront(nil)

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
