import AppKit
import CoreGraphics

struct FullscreenAppInspector {
    /// 检测指定显示器上是否有全屏应用
    /// - Parameter displayFrame: 要检测的显示器 frame
    /// - Returns: 如果检测到全屏应用返回 true
    ///
    /// 注意：此方法会检测前台应用是否有窗口完全覆盖指定显示器。
    /// 如果前台应用没有可见窗口，或者窗口尺寸不匹配显示器，
    /// 则认为没有全屏应用。
    func isLikelyFullscreenAppActive(on displayFrame: CGRect) -> Bool {
        guard let frontmostApp = NSWorkspace.shared.frontmostApplication else {
            return false
        }

        // 如果前台应用是本应用，不认为是全屏应用
        if frontmostApp.bundleIdentifier == Bundle.main.bundleIdentifier {
            return false
        }

        guard let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] else {
            return false
        }

        for info in windowList {
            let ownerPID = info[kCGWindowOwnerPID as String] as? pid_t ?? 0
            let layer = info[kCGWindowLayer as String] as? Int ?? -1
            let alpha = info[kCGWindowAlpha as String] as? CGFloat ?? 0

            guard ownerPID == frontmostApp.processIdentifier else {
                continue
            }

            // 检查窗口是否可见（layer 0 是普通窗口，alpha > 0 表示可见）
            guard layer == 0, alpha > 0 else {
                continue
            }

            guard
                let boundsDict = info[kCGWindowBounds as String] as? NSDictionary,
                let bounds = CGRect(dictionaryRepresentation: boundsDict)
            else {
                continue
            }

            // 检查窗口是否覆盖整个显示器（允许 8 点误差）
            if bounds.width >= displayFrame.width - 8,
               bounds.height >= displayFrame.height - 8 {
                return true
            }
        }

        // 如果前台应用没有任何可见窗口，可能是在应用切换过程中
        // 此时不应误判为没有全屏应用，返回上一个状态或 true 以避免闪屏
        // 但为了避免误判，我们返回 false，让调用方通过防抖机制处理
        return false
    }

    /// 检测是否有任何应用在全屏模式下运行（不限于指定显示器）
    /// 用于判断系统是否处于全屏应用切换的敏感时期
    func isAnyFullscreenAppActive() -> Bool {
        guard let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] else {
            return false
        }

        let screens = NSScreen.screens
        guard !screens.isEmpty else { return false }

        let screenSizes = screens.compactMap { $0.frame.size }

        for info in windowList {
            let layer = info[kCGWindowLayer as String] as? Int ?? -1
            let alpha = info[kCGWindowAlpha as String] as? CGFloat ?? 0

            guard layer == 0, alpha > 0 else {
                continue
            }

            guard
                let boundsDict = info[kCGWindowBounds as String] as? NSDictionary,
                let bounds = CGRect(dictionaryRepresentation: boundsDict)
            else {
                continue
            }

            // 检查窗口是否匹配任何屏幕尺寸（全屏窗口）
            for screenSize in screenSizes {
                if abs(bounds.width - screenSize.width) <= 8,
                   abs(bounds.height - screenSize.height) <= 8 {
                    return true
                }
            }
        }

        return false
    }
}
