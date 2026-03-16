import AppKit
import CoreGraphics

@MainActor
final class DesktopWindowManager {
    private var desktopWindows: [CGDirectDisplayID: NSWindow] = [:]
    private var screenObserver: NSObjectProtocol?
    private var spaceObserver: NSObjectProtocol?
    private var activeAppObserver: NSObjectProtocol?
    private var currentDisplayIDs: [CGDirectDisplayID] = []
    private var currentLayerStrategy: WindowLayerStrategy = .belowDesktopIcons
    private let windowInspector = DesktopWindowInspector()
    var onWindowStateChange: (() -> Void)?
    var onDiagnosticEvent: ((String) -> Void)?
    var onEnvironmentChange: ((String) -> Void)?

    deinit {
        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
        }
        if let spaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(spaceObserver)
        }
        if let activeAppObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(activeAppObserver)
        }
    }

    func prepareDesktopHostViews(
        on displayID: CGDirectDisplayID?,
        layerStrategy: WindowLayerStrategy,
        applyToAllDisplays: Bool
    ) throws -> [NSView] {
        let screens = resolveScreens(for: displayID, applyToAllDisplays: applyToAllDisplays)
        guard !screens.isEmpty else {
            throw WallpaperPrototypeError.noMainScreen
        }

        currentDisplayIDs = screens.compactMap { DisplayTarget(screen: $0)?.id }
        currentLayerStrategy = layerStrategy

        let targetIDs = Set(currentDisplayIDs)
        for staleID in Array(desktopWindows.keys) where !targetIDs.contains(staleID) {
            desktopWindows[staleID]?.orderOut(nil)
            desktopWindows[staleID]?.contentView = nil
            desktopWindows.removeValue(forKey: staleID)
        }

        var hostViews: [NSView] = []

        for screen in screens {
            guard let displayTarget = DisplayTarget(screen: screen) else { continue }

            let window = desktopWindows[displayTarget.id] ?? WallpaperDesktopWindow(
                contentRect: screen.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false,
                screen: screen
            )

            window.isReleasedWhenClosed = false
            window.backgroundColor = .black
            window.isOpaque = true
            window.hasShadow = false
            window.ignoresMouseEvents = true
            window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
            window.level = NSWindow.Level(rawValue: layerStrategy.level)
            window.setFrame(screen.frame, display: true)

            let contentView = NSView(frame: localContentRect(for: screen.frame))
            contentView.wantsLayer = true
            window.contentView = contentView
            window.orderFrontRegardless()
            window.orderBack(nil)

            desktopWindows[displayTarget.id] = window
            hostViews.append(contentView)
        }

        installObserversIfNeeded()
        onDiagnosticEvent?("已在 \(hostViews.count) 个显示器上准备桌面窗口，策略：\(layerStrategy.title)。")
        onWindowStateChange?()
        return hostViews
    }

    func destroyDesktopWindow() {
        for (displayID, desktopWindow) in desktopWindows {
            desktopWindow.orderOut(nil)
            desktopWindow.contentView = nil
            desktopWindows.removeValue(forKey: displayID)
        }
        onDiagnosticEvent?("桌面窗口已销毁。")
        onWindowStateChange?()
    }

    func setDesktopWindowHidden(_ hidden: Bool) {
        guard !desktopWindows.isEmpty else { return }

        for desktopWindow in desktopWindows.values {
            if hidden {
                desktopWindow.orderOut(nil)
            } else {
                desktopWindow.orderFrontRegardless()
                desktopWindow.orderBack(nil)
            }
        }

        onDiagnosticEvent?(hidden ? "桌面窗口已隐藏。" : "桌面窗口已显示。")
        onWindowStateChange?()
    }

    func snapshot() -> DesktopWindowCollectionSnapshot? {
        guard !desktopWindows.isEmpty else { return nil }

        let windows = desktopWindows.compactMap { displayID, desktopWindow -> DesktopWindowSnapshot? in
            DesktopWindowSnapshot(
                displayName: displayName(for: displayID),
                frame: desktopWindow.frame,
                level: desktopWindow.level.rawValue,
                strategyTitle: currentLayerStrategy.title,
                serverSummary: windowInspector.snapshot(for: desktopWindow.windowNumber)?.summary
            )
        }

        return DesktopWindowCollectionSnapshot(windows: windows.sorted { $0.displayName < $1.displayName })
    }

    func currentDesktopWindowCount() -> Int {
        // 只统计真正可见的窗口数量
        let count = desktopWindows.values.filter { $0.isVisible }.count
        return count
    }

    func hasValidDesktopWindows() -> Bool {
        let hasValid = !desktopWindows.isEmpty && desktopWindows.values.contains { $0.isVisible }
        return hasValid
    }

    /// 获取窗口状态摘要，用于调试
    func getWindowStatusSummary() -> String {
        guard !desktopWindows.isEmpty else {
            return "无桌面窗口"
        }

        var summaries: [String] = []

        for (displayID, window) in desktopWindows {
            let name = displayName(for: displayID)
            let isVisible = window.isVisible
            let frame = window.frame

            // 获取子图层信息
            var sublayerInfo = "无图层"
            if let contentView = window.contentView,
               let layer = contentView.layer,
               let sublayers = layer.sublayers {
                let frames = sublayers.map { "\(Int($0.frame.width))x\(Int($0.frame.height))" }
                sublayerInfo = "子图层[\(sublayers.count)]: " + frames.joined(separator: ",")
            }

            summaries.append("\(name): 可见=\(isVisible), frame=\(Int(frame.width))x\(Int(frame.height)), \(sublayerInfo)")
        }
        return summaries.joined(separator: "; ")
    }

    private func resolveScreens(for displayID: CGDirectDisplayID?, applyToAllDisplays: Bool) -> [NSScreen] {
        if applyToAllDisplays {
            return NSScreen.screens
        }

        if let displayID {
            let matchedScreen = NSScreen.screens.first { screen in
                guard let target = DisplayTarget(screen: screen) else { return false }
                return target.id == displayID
            }

            if let matchedScreen {
                return [matchedScreen]
            }
        }

        if let main = NSScreen.main {
            return [main]
        }

        return NSScreen.screens.isEmpty ? [] : [NSScreen.screens[0]]
    }

    private func displayName(for displayID: CGDirectDisplayID) -> String {
        NSScreen.screens
            .compactMap(DisplayTarget.init(screen:))
            .first(where: { $0.id == displayID })?
            .name ?? "未知显示器"
    }

    private func installObserversIfNeeded() {
        installScreenObserverIfNeeded()
        installWorkspaceObserversIfNeeded()
    }

    private func installScreenObserverIfNeeded() {
        guard screenObserver == nil else { return }

        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshDesktopWindowFrame()
                self?.onDiagnosticEvent?("显示器参数已变化。")
                self?.onEnvironmentChange?("screen-parameters")
                self?.onWindowStateChange?()
            }
        }
    }

    private func installWorkspaceObserversIfNeeded() {
        let workspaceCenter = NSWorkspace.shared.notificationCenter

        if spaceObserver == nil {
            spaceObserver = workspaceCenter.addObserver(
                forName: NSWorkspace.activeSpaceDidChangeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.refreshDesktopWindowFrame()
                    self?.onDiagnosticEvent?("当前空间已变化。")
                    self?.onEnvironmentChange?("active-space")
                    self?.onWindowStateChange?()
                }
            }
        }

        if activeAppObserver == nil {
            activeAppObserver = workspaceCenter.addObserver(
                forName: NSWorkspace.didActivateApplicationNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.onDiagnosticEvent?("前台应用已变化。")
                    self?.onEnvironmentChange?("frontmost-app")
                    self?.onWindowStateChange?()
                }
            }
        }
    }

    private func refreshDesktopWindowFrame() {
        let screens = resolveScreens(
            for: currentDisplayIDs.first,
            applyToAllDisplays: currentDisplayIDs.count > 1
        )

        for screen in screens {
            guard let displayTarget = DisplayTarget(screen: screen),
                  let desktopWindow = desktopWindows[displayTarget.id]
            else { continue }

            desktopWindow.setFrame(screen.frame, display: true)
            desktopWindow.contentView?.frame = localContentRect(for: screen.frame)
            desktopWindow.contentView?.layer?.frame = desktopWindow.contentView?.bounds ?? .zero
        }
    }

    /// 确保所有桌面窗口都正确显示在屏幕上
    /// 在 Space 切换后调用，重新将窗口放到正确的层级
    func ensureWindowsVisible() {
        guard !desktopWindows.isEmpty else { return }

        // 重新获取当前所有屏幕
        let currentScreens = NSScreen.screens

        for (displayID, desktopWindow) in desktopWindows {
            // 找到对应的屏幕
            if let screen = currentScreens.first(where: { DisplayTarget(screen: $0)?.id == displayID }) {
                let correctFrame = screen.frame
                let currentFrame = desktopWindow.frame

                // 检查 frame 是否有显著差异
                let frameChanged = abs(currentFrame.origin.x - correctFrame.origin.x) > 1 ||
                                   abs(currentFrame.origin.y - correctFrame.origin.y) > 1 ||
                                   abs(currentFrame.width - correctFrame.width) > 1 ||
                                   abs(currentFrame.height - correctFrame.height) > 1

                if frameChanged {
                    onDiagnosticEvent?("窗口 frame 需要修正: (\(currentFrame.origin.x), \(currentFrame.origin.y), \(currentFrame.width)x\(currentFrame.height)) -> (\(correctFrame.origin.x), \(correctFrame.origin.y), \(correctFrame.width)x\(correctFrame.height))")
                    desktopWindow.setFrame(correctFrame, display: true)
                }

                // 确保 contentView 有正确的尺寸
                if let contentView = desktopWindow.contentView {
                    let localRect = localContentRect(for: correctFrame)
                    if contentView.frame != localRect {
                        contentView.frame = localRect
                    }
                    contentView.layer?.frame = contentView.bounds
                    contentView.layer?.bounds = contentView.bounds
                    // 强制更新图层
                    contentView.needsLayout = true
                    contentView.layoutSubtreeIfNeeded()
                }
            } else {
                // 找不到对应屏幕，可能显示器断开了
                onDiagnosticEvent?("找不到显示器 ID: \(displayID)")
            }

            // 强制将窗口放到桌面层级
            desktopWindow.orderFrontRegardless()
            desktopWindow.orderBack(nil)
        }

        onDiagnosticEvent?("已重新确保桌面窗口可见。")
    }

    /// 强制刷新所有窗口的图层尺寸
    func forceRefreshLayerFrames() {
        let currentScreens = NSScreen.screens

        for (displayID, desktopWindow) in desktopWindows {
            if let screen = currentScreens.first(where: { DisplayTarget(screen: $0)?.id == displayID }) {
                let correctFrame = screen.frame

                // 强制设置正确的 frame
                desktopWindow.setFrame(correctFrame, display: true)

                if let contentView = desktopWindow.contentView {
                    let localRect = localContentRect(for: correctFrame)
                    contentView.frame = localRect
                    contentView.needsLayout = true
                    contentView.layoutSubtreeIfNeeded()

                    // 强制更新所有子图层
                    if let layer = contentView.layer {
                        layer.frame = contentView.bounds
                        layer.bounds = contentView.bounds

                        // 强制更新每个子图层
                        if let sublayers = layer.sublayers {
                            for sublayer in sublayers {
                                sublayer.frame = layer.bounds
                                sublayer.bounds = layer.bounds
                                sublayer.setNeedsDisplay()
                            }
                        }
                    }
                }
            }
        }
    }

    /// 检查指定显示器的窗口是否在当前 Space 上可见
    func isWindowVisibleOnCurrentSpace(for displayID: CGDirectDisplayID) -> Bool {
        guard let window = desktopWindows[displayID] else { return false }

        // 检查窗口是否可见
        guard window.isVisible else {
            onDiagnosticEvent?("窗口不可见")
            return false
        }

        // 检查窗口 frame 是否有效（不能太小）
        let minValidSize: CGFloat = 100
        guard window.frame.width > minValidSize, window.frame.height > minValidSize else {
            onDiagnosticEvent?("窗口 frame 太小: \(window.frame)")
            return false
        }

        // 检查窗口是否有内容视图
        guard let contentView = window.contentView else {
            onDiagnosticEvent?("没有 contentView")
            return false
        }

        // 检查 contentView 的 frame 是否正确
        guard contentView.frame.width > minValidSize, contentView.frame.height > minValidSize else {
            onDiagnosticEvent?("contentView frame 太小: \(contentView.frame)")
            return false
        }

        // 检查窗口是否有图层
        guard let layer = contentView.layer else {
            onDiagnosticEvent?("没有 layer")
            return false
        }

        // 检查图层是否有子图层（AVPlayerLayer）
        guard let sublayers = layer.sublayers, !sublayers.isEmpty else {
            onDiagnosticEvent?("没有子图层")
            return false
        }

        // 检查子图层的大小是否正确
        for (index, sublayer) in sublayers.enumerated() {
            if sublayer.frame.width < minValidSize || sublayer.frame.height < minValidSize {
                onDiagnosticEvent?("子图层[\(index)] frame 太小: \(sublayer.frame)")
                return false
            }
        }

        return true
    }

    /// 检查窗口的详细状态，返回诊断字符串
    func getDetailedWindowStatus(for displayID: CGDirectDisplayID) -> String {
        guard let window = desktopWindows[displayID] else {
            return "窗口不存在"
        }

        var status: [String] = []
        status.append("isVisible=\(window.isVisible)")
        status.append("frame=\(Int(window.frame.width))x\(Int(window.frame.height))")

        if let contentView = window.contentView {
            status.append("contentView.frame=\(Int(contentView.frame.width))x\(Int(contentView.frame.height))")
            if let layer = contentView.layer {
                status.append("layer.frame=\(Int(layer.frame.width))x\(Int(layer.frame.height))")
                if let sublayers = layer.sublayers {
                    status.append("sublayers.count=\(sublayers.count)")
                    for (i, sublayer) in sublayers.enumerated() {
                        status.append("sublayer[\(i)].frame=\(Int(sublayer.frame.width))x\(Int(sublayer.frame.height))")
                    }
                } else {
                    status.append("sublayers=nil")
                }
            } else {
                status.append("layer=nil")
            }
        } else {
            status.append("contentView=nil")
        }

        return status.joined(separator: ", ")
    }

    private func localContentRect(for screenFrame: CGRect) -> CGRect {
        CGRect(origin: .zero, size: screenFrame.size)
    }
}

final class WallpaperDesktopWindow: NSWindow {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
