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
    private var appearanceObservation: NSKeyValueObservation?

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
        window.level = .normal
        window.hasShadow = false  // No shadow like Weather widget
        window.isMovableByWindowBackground = true
        window.collectionBehavior = [.ignoresCycle]

        // Restore position or center
        window.setFrameAutosaveName("MoltyMeterWindow")
        if window.frame.origin == .zero {
            window.center()
        }

        // Container with rounded corners and solid translucent background
        let containerView = NSView(frame: window.contentView!.bounds)
        containerView.autoresizingMask = [.width, .height]
        containerView.wantsLayer = true
        containerView.layer?.cornerRadius = 20
        containerView.layer?.masksToBounds = true

        // Set initial background based on appearance
        updateBackgroundForAppearance(containerView: containerView)

        // Observe appearance changes
        appearanceObservation = NSApp.observe(\.effectiveAppearance) { [weak self, weak containerView] _, _ in
            Task { @MainActor in
                if let containerView = containerView {
                    self?.updateBackgroundForAppearance(containerView: containerView)
                }
            }
        }

        // SwiftUI content
        let hostingView = NSHostingView(rootView: MoltyView(data: dataProvider))
        hostingView.frame = containerView.bounds
        hostingView.autoresizingMask = [.width, .height]
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = .clear

        containerView.addSubview(hostingView)
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

    private func updateBackgroundForAppearance(containerView: NSView) {
        let isDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua

        if isDark {
            // Dark mode: pure black (#000) semi-transparent background
            containerView.layer?.backgroundColor = NSColor(white: 0.0, alpha: 0.8).cgColor
        } else {
            // Light mode: white semi-transparent background
            containerView.layer?.backgroundColor = NSColor(white: 1.0, alpha: 0.8).cgColor
        }
    }
}
