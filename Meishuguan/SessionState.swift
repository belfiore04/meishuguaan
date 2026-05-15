import SwiftUI
import Observation

@Observable
final class SessionState {
    enum Stage {
        case start
        case capturing
        case identifying
        case chatting
        case generating
        case showingExhibit
        case gallery
    }

    var stage: Stage = .start
    var currentBook: Book?
    var messages: [ChatMessage] = []
    var generationProgress: Double = 0
    var generationStatusText: String = ""
    var currentExhibit: Exhibit?
    var exhibits: [Exhibit] = []     // 启动时从盘加载
    var galleryIndex: Int = 0
    var lastError: String?

    init() {
        self.exhibits = Self.loadOrSeed()
    }

    /// 同步从 Documents/Exhibits/index.json 读 exhibits。
    /// 没文件 → 首次启动，注入 mock 并写盘。
    /// 文件解码失败 → 当作首次启动处理（容错）。
    private static func loadOrSeed() -> [Exhibit] {
        let url = indexURL
        if let data = try? Data(contentsOf: url),
           let loaded = try? JSONDecoder().decode([Exhibit].self, from: data) {
            return loaded
        }
        let mocks = SeedData.makeMockExhibits()
        saveSync(mocks)
        return mocks
    }

    /// 把当前 exhibits 异步写盘。append 完调一下。
    func persist() {
        let snapshot = exhibits
        Task.detached(priority: .utility) {
            Self.saveSync(snapshot)
        }
    }

    /// 把生成完的展品 append 到展厅末尾，同步更新 galleryIndex，并持久化。
    func appendExhibit(_ exhibit: Exhibit) {
        exhibits.append(exhibit)
        galleryIndex = exhibits.count - 1
        persist()
    }

    private static var indexURL: URL {
        Exhibit.exhibitsDirectory.appendingPathComponent("index.json")
    }

    private static func saveSync(_ exhibits: [Exhibit]) {
        let url = indexURL
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        guard let data = try? JSONEncoder().encode(exhibits) else { return }
        try? data.write(to: url, options: .atomic)
    }

    /// 一次读书结束，回大厅；保留 exhibits 让用户能进展厅看。
    func returnToLobby() {
        stage = .start
        currentBook = nil
        messages = []
        generationProgress = 0
        generationStatusText = ""
        currentExhibit = nil
        lastError = nil
    }

    /// 完整重置，包含 exhibits。v1 实际没人调，留个口。
    func reset() {
        returnToLobby()
        exhibits = []
        galleryIndex = 0
    }
}
