import AppKit
import CoreGraphics

struct WindowServerSnapshot {
    let windowNumber: Int
    let layer: Int
    let ownerPID: Int
    let alpha: Double
    let isOnscreen: Bool

    var summary: String {
        "窗口 #\(windowNumber) | 服务层级 \(layer) | 透明度 \(String(format: "%.2f", alpha)) | 屏幕上 \(isOnscreen ? "是" : "否") | pid \(ownerPID)"
    }
}

struct DesktopWindowInspector {
    func snapshot(for windowNumber: Int) -> WindowServerSnapshot? {
        let options: CGWindowListOption = [.optionIncludingWindow]
        guard let infoList = CGWindowListCopyWindowInfo(options, CGWindowID(windowNumber)) as? [[String: Any]],
              let info = infoList.first
        else {
            return nil
        }

        let layer = info[kCGWindowLayer as String] as? Int ?? -1
        let ownerPID = info[kCGWindowOwnerPID as String] as? Int ?? -1
        let alpha = info[kCGWindowAlpha as String] as? Double ?? 0
        let isOnscreen = info[kCGWindowIsOnscreen as String] as? Bool ?? false

        return WindowServerSnapshot(
            windowNumber: windowNumber,
            layer: layer,
            ownerPID: ownerPID,
            alpha: alpha,
            isOnscreen: isOnscreen
        )
    }
}
