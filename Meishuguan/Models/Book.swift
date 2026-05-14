import Foundation
import UIKit

struct Book: Identifiable, Hashable {
    let id = UUID()
    var title: String
    var author: String?
    var brief: String  // 一两句话的背景，用于注入给 AI
    var coverImage: UIImage?
    var dominantColors: [CGFloatRGB] = []
}

struct CGFloatRGB: Hashable {
    var r: Double
    var g: Double
    var b: Double
}
