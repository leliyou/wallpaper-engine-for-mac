import Foundation

struct EventLogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let message: String

    var summary: String {
        "\(Self.formatter.string(from: timestamp))  \(message)"
    }

    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()
}
