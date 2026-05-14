import Foundation

struct Exhibit: Identifiable {
    let id = UUID()
    var book: Book
    var noteText: String        // 粘在展台正面的纸 — 这次会话整理出的笔记
    var objectPrompt: String    // 喂给图像/3D 模型的英文 prompt
    var imageLocalURL: URL?     // 2D 图（Pollinations / Replicate 路径）
    var modelLocalURL: URL?     // .usdz/.glb（Meshy 等 3D 路径，未来用）
    var generatedAt: Date = Date()
}
