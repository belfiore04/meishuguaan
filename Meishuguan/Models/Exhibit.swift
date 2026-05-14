import Foundation

struct Exhibit: Identifiable {
    let id = UUID()
    var book: Book
    var noteText: String        // 粘在展台正面的纸 — 这次会话整理出的笔记
    var objectPrompt: String    // 喂给 Meshy 的 prompt，例如 "a low-poly white ruler with copper details"
    var modelLocalURL: URL?     // 下载到本地的 .usdz 文件
    var generatedAt: Date = Date()
}
