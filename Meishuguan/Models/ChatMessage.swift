import Foundation

struct ChatMessage: Identifiable, Hashable, Codable {
    var id = UUID()
    let role: Role
    var text: String
    let timestamp: Date

    init(role: Role, text: String, timestamp: Date = Date()) {
        self.role = role
        self.text = text
        self.timestamp = timestamp
    }

    enum Role: String, Hashable, Codable {
        case user
        case assistant
    }
}
