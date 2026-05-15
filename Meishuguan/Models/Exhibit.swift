import Foundation

struct Exhibit: Identifiable, Codable {
    var id = UUID()
    var book: Book
    var noteText: String         // 粘在展台正面的纸 — 这次会话整理出的笔记
    var objectPrompt: String     // 喂给图像/3D 模型的英文 prompt
    var imageFilename: String?   // Documents/Exhibits/ 下的文件名（不存绝对路径，重装后路径会变）
    var modelFilename: String?
    var fallbackSymbol: String?  // 没有真图时的 SF Symbol 占位（mock 数据用）
    var generatedAt: Date = Date()

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
