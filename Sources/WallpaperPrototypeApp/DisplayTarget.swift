import AppKit

struct DisplayTarget: Identifiable, Equatable {
    let id: CGDirectDisplayID
    let name: String
    let frame: CGRect

    init?(screen: NSScreen) {
        guard let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            return nil
        }

        id = CGDirectDisplayID(screenNumber.uint32Value)
        name = screen.localizedName
        frame = screen.frame
    }

    var summary: String {
        "\(name)（\(Int(frame.width))x\(Int(frame.height))）"
    }
}

struct DesktopWindowSnapshot {
    let displayName: String
    let frame: CGRect
    let level: Int
    let strategyTitle: String
    let serverSummary: String?

    var summary: String {
        let base = "\(displayName) | \(Int(frame.width))x\(Int(frame.height)) | \(strategyTitle) | 层级 \(level)"
        guard let serverSummary else { return base }
        return "\(base) | \(serverSummary)"
    }
}

struct DesktopWindowCollectionSnapshot {
    let windows: [DesktopWindowSnapshot]

    var summary: String {
        guard !windows.isEmpty else { return "当前没有附着桌面窗口。" }
        if windows.count == 1 {
            return windows[0].summary
        }

        return windows.map(\.summary).joined(separator: " || ")
    }
}

enum WindowLayerStrategy: String, CaseIterable, Identifiable {
    case desktopWindow
    case belowDesktopIcons
    case desktopIconWindow

    var id: String { rawValue }

    var title: String {
        switch self {
        case .desktopWindow:
            return "桌面窗口"
        case .belowDesktopIcons:
            return "图标下层"
        case .desktopIconWindow:
            return "图标同层"
        }
    }

    var level: Int {
        switch self {
        case .desktopWindow:
            return Int(CGWindowLevelForKey(.desktopWindow))
        case .belowDesktopIcons:
            return Int(CGWindowLevelForKey(.desktopIconWindow)) - 1
        case .desktopIconWindow:
            return Int(CGWindowLevelForKey(.desktopIconWindow))
        }
    }
}
