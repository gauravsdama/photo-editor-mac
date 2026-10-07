import Foundation

struct CommandLogEntry: Identifiable {
    let id = UUID()
    let timestamp = Date()
    let title: String
    let detail: String?

    var apiRepresentation: JSONObject {
        let payload: JSONObject = [
            "id": .string(id.uuidString),
            "timestamp": .string(ISO8601DateFormatter().string(from: timestamp)),
            "title": .string(title)
        ]
        return payload
    }
}
