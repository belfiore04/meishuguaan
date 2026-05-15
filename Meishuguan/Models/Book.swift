import Foundation
import UIKit

struct Book: Identifiable, Hashable {
    let id = UUID()
    var title: String
    var author: String?
    var brief: String  // 一两句话的背景，用于注入给 AI
    var coverImage: UIImage?
    var dominantColors: [CGFloatRGB] = []

    // UIImage 不 conform Hashable，所以手写一下：用 id 唯一标识就够了。
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: Book, rhs: Book) -> Bool { lhs.id == rhs.id }
}

struct CGFloatRGB: Hashable {
    var r: Double
    var g: Double
    var b: Double
}
