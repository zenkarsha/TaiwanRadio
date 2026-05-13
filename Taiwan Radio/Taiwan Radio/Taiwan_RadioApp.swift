//
//  Taiwan_RadioApp.swift
//  Taiwan Radio
//
//  Created by marc huang on 2026/4/10.
//

import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.appearance = NSAppearance(named: .darkAqua)
        NSApp.setActivationPolicy(.regular)
        showMainWindow()
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            showMainWindow()
            NSApp.activate(ignoringOtherApps: true)
        }

        return true
    }

    private func showMainWindow() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            return
        }

        let contentView = ContentView()
        let hostingController = NSHostingController(rootView: contentView)
        hostingController.view.appearance = NSAppearance(named: .darkAqua)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 640),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.title = "Taiwan Radio"
        window.center()
        window.minSize = NSSize(width: 520, height: 640)
        window.appearance = NSAppearance(named: .darkAqua)
        window.contentViewController = hostingController
        window.isReleasedWhenClosed = false
        window.isRestorable = false
        window.identifier = NSUserInterfaceItemIdentifier("main-window")
        window.makeKeyAndOrderFront(nil)

        self.window = window
    }
}

@main
struct Taiwan_RadioApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
