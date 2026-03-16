import Foundation

enum PlaylistMode: String, CaseIterable, Identifiable {
    case sequential
    case shuffle

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sequential:
            return "顺序"
        case .shuffle:
            return "随机"
        }
    }
}
