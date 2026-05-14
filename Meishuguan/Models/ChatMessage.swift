import Foundation

struct ChatMessage: Identifiable, Hashable {
    let id = UUID()
    let role: Role
    var text: String
    let timestamp: Date = Date()

    enum Role: String, Hashable {
        case user
        case assistant
    }
}
