import Foundation

enum WallpaperPrototypeError: LocalizedError {
    case noMainScreen
    case invalidVideoURL

    var errorDescription: String? {
        switch self {
        case .noMainScreen:
            return "当前没有可用于动态壁纸的主显示器。"
        case .invalidVideoURL:
            return "已保存的视频路径已失效。"
        }
    }
}
