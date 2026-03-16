import AppKit
import SwiftUI

@main
struct WallpaperPrototypeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private let coordinator = WallpaperCoordinator()

    var body: some Scene {
        let _ = appDelegate.configure(with: coordinator)

        WindowGroup("动态壁纸原型") {
            ContentView(coordinator: coordinator)
                .frame(minWidth: 720, minHeight: 760)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    weak var coordinator: WallpaperCoordinator?

    private var statusItem: NSStatusItem?
    private var manuallyManagedWindow: NSWindow?
    private weak var primaryWindow: NSWindow?
    private var didConfigure = false

    func configure(with coordinator: WallpaperCoordinator) {
        self.coordinator = coordinator

        guard !didConfigure else { return }
        didConfigure = true
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        attachToExistingMainWindowIfNeeded()
    }

    func applicationWillTerminate(_ notification: Notification) {
        coordinator?.stopPlayback()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            openMainWindow()
        }
        return true
    }

    func windowWillClose(_ notification: Notification) {
        if let window = notification.object as? NSWindow, window == manuallyManagedWindow {
            manuallyManagedWindow = nil
        }
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if sender == primaryWindow || sender == manuallyManagedWindow {
            sender.orderOut(nil)
            return false
        }

        return true
    }

    @objc func openMainWindow() {
        NSApp.activate(ignoringOtherApps: true)

        if let existingWindow = NSApp.windows.first(where: { $0.canBecomeMain && $0 !== manuallyManagedWindow }) {
            existingWindow.delegate = self
            primaryWindow = existingWindow
            existingWindow.makeKeyAndOrderFront(nil)
            return
        }

        if let manuallyManagedWindow {
            manuallyManagedWindow.delegate = self
            manuallyManagedWindow.makeKeyAndOrderFront(nil)
            return
        }

        guard let coordinator else { return }

        let contentView = ContentView(coordinator: coordinator)
            .frame(minWidth: 720, minHeight: 760)
        let hostingController = NSHostingController(rootView: contentView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 820),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "动态壁纸原型"
        window.contentViewController = hostingController
        window.delegate = self
        window.makeKeyAndOrderFront(nil)

        manuallyManagedWindow = window
    }

    @objc func applyToDesktop() {
        coordinator?.applySelectedVideo()
    }

    @objc func stopPlayback() {
        coordinator?.stopPlayback()
    }

    @objc func playPrevious() {
        coordinator?.playPreviousVideoManually()
    }

    @objc func playNext() {
        coordinator?.playNextVideoManually()
    }

    @objc func terminateApp() {
        NSApp.terminate(nil)
    }

    private func setupStatusItem() {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(systemSymbolName: "play.rectangle", accessibilityDescription: "动态壁纸原型")
        statusItem.button?.toolTip = "动态壁纸原型"

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "打开主窗口", action: #selector(openMainWindow), keyEquivalent: "o"))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "应用到桌面", action: #selector(applyToDesktop), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "停止播放", action: #selector(stopPlayback), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "上一个", action: #selector(playPrevious), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "下一个", action: #selector(playNext), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "退出", action: #selector(terminateApp), keyEquivalent: "q"))

        for item in menu.items {
            item.target = self
        }

        statusItem.menu = menu
        self.statusItem = statusItem
    }

    private func attachToExistingMainWindowIfNeeded() {
        guard primaryWindow == nil else { return }

        if let window = NSApp.windows.first(where: { $0.canBecomeMain && $0 !== manuallyManagedWindow }) {
            window.delegate = self
            primaryWindow = window
        }
    }
}
