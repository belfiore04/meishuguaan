import Foundation
import UIKit

struct Book: Identifiable, Hashable, Codable {
    var id = UUID()
    var title: String
    var author: String?
    var brief: String  // 一两句话的背景，用于注入给 AI
    var coverImage: UIImage? = nil  // 不持久化，仅运行时用
    var dominantColors: [CGFloatRGB] = []

    // 持久化时只编码这些字段；coverImage 是 UIImage 既不 Codable 也不 Hashable，跳过。
    enum CodingKeys: String, CodingKey {
        case id, title, author, brief, dominantColors
    }

    // UIImage 不 conform Hashable，手写：用 id 唯一标识。
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: Book, rhs: Book) -> Bool { lhs.id == rhs.id }
}

struct CGFloatRGB: Hashable, Codable {
    var r: Double
    var g: Double
    var b: Double
}
