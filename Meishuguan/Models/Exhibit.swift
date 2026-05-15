import Foundation

struct Exhibit: Identifiable, Codable {
    var id = UUID()
    var book: Book
    var objectName: String       // 展品名（策展人凝出的 2-4 字中文，可由读者改一次）
    var noteText: String         // 展品说明卡正文（策展人笔触的 200-300 字）
    var objectPrompt: String     // 喂给图像/3D 模型的英文 prompt
    var imageFilename: String?   // Documents/Exhibits/ 下的文件名（不存绝对路径，重装后路径会变）
    var modelFilename: String?
    var fallbackSymbol: String?  // 没有真图时的 SF Symbol 占位（mock 数据用）
    var messages: [ChatMessage] = []   // 这次阅读的完整对话，供"看完整对话"展开
    var startedAt: Date?         // 阅读开始（进入 chatting 那一刻）
    var generatedAt: Date = Date()   // 阅读结束 = 展品生成时间

    /// 展品文件目录。
    static var exhibitsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Exhibits", isDirectory: true)
    }

    /// 拼出图片完整 URL，view 用。
    var imageLocalURL: URL? {
        imageFilename.map { Self.exhibitsDirectory.appendingPathComponent($0) }
    }

    var modelLocalURL: URL? {
        modelFilename.map { Self.exhibitsDirectory.appendingPathComponent($0) }
    }
}
