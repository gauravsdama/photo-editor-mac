import Foundation

struct CommandLogEntry: Identifiable {
    let id = UUID()
    let timestamp = Date()
    let title: String
    let detail: String?

    var apiRepresentation: [String: Any] {
        var payload: [String: Any] = [
            "id": id.uuidString,
            "timestamp": ISO8601DateFormatter().string(from: timestamp),
            "title": title
        ]
        if let detail {
            payload["detail"] = detail
        }
        return payload
    }
}
