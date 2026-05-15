import SwiftUI
import Observation

@Observable
final class SessionState {
    enum Stage {
        case start
        case capturing
        case identifying
        case confirming       // 拍完书后让用户确认是不是这本（同书/新书）
        case chatting
        case generating
        case showingExhibit
        case gallery          // 展厅：一本书的所有展品左右滑
    }

    var stage: Stage = .start
    var currentBook: Book?
    var pendingBook: Book?            // 识别完待用户确认的书
    var messages: [ChatMessage] = []
    var generationProgress: Double = 0
    var generationStatusText: String = ""
    var currentExhibit: Exhibit?
    var exhibits: [Exhibit] = []      // 启动时从盘加载，是整个 app（展馆）的所有展品
    var activeGalleryKey: String?     // 当前展厅的 normalized title key（哪本书）
    var galleryIndex: Int = 0         // 当前展厅内看到第几件展品
    var readingStartedAt: Date?
    var deepMode: Bool = false
    var lastError: String?

    init() {
        self.exhibits = Self.loadOrSeed()
    }

    // MARK: - 展厅分组（按书）

    /// 一个展厅 = 一本书 + 这本书的所有展品。
    struct Gallery: Identifiable {
        var id: String { titleKey }
        let titleKey: String
        let book: Book           // 用最近一次的 metadata
        let exhibits: [Exhibit]  // 按时间升序
        var latestAt: Date { exhibits.map(\.generatedAt).max() ?? .distantPast }
    }

    /// 整个展馆的所有展厅，按"最近活跃"倒序。
    var galleries: [Gallery] {
        let groups = Dictionary(grouping: exhibits) { $0.book.title.normalizedTitleKey }
        return groups.map { key, list in
            let sorted = list.sorted { $0.generatedAt < $1.generatedAt }
            return Gallery(
                titleKey: key,
                book: sorted.last?.book ?? sorted.first!.book,
                exhibits: sorted
            )
        }
        .sorted { $0.latestAt > $1.latestAt }
    }

    /// 根据 Qwen-VL 返回的 title 查找匹配的展厅。
    func findGallery(matchingTitle title: String) -> Gallery? {
        let key = title.normalizedTitleKey
        return galleries.first { $0.titleKey == key }
    }

    /// 取出 activeGalleryKey 对应的展厅。
    var activeGallery: Gallery? {
        guard let key = activeGalleryKey else { return nil }
        return galleries.first { $0.titleKey == key }
    }

    // MARK: - 状态切换

    /// 一次读书结束，回大厅；保留 exhibits 让用户能进展厅看。
    func returnToLobby() {
        stage = .start
        currentBook = nil
        pendingBook = nil
        messages = []
        readingStartedAt = nil
        deepMode = false
        generationProgress = 0
        generationStatusText = ""
        currentExhibit = nil
        activeGalleryKey = nil
        lastError = nil
    }

    /// 完整重置，包含 exhibits。v1 实际没人调，留个口。
    func reset() {
        returnToLobby()
        exhibits = []
        galleryIndex = 0
    }

    /// 把生成完的展品 append 到展馆末尾，并持久化。
    /// 同步设置 activeGalleryKey + galleryIndex 让"看展品"能直接进入这件。
    func appendExhibit(_ exhibit: Exhibit) {
        exhibits.append(exhibit)
        let key = exhibit.book.title.normalizedTitleKey
        activeGalleryKey = key
        // 新 append 的展品在它所在展厅内的 index
        if let gallery = galleries.first(where: { $0.titleKey == key }) {
            galleryIndex = max(0, gallery.exhibits.count - 1)
        }
        persist()
    }

    /// 用户在展台说明里改了展品名后回写。
    func renameExhibit(id: UUID, to newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard let idx = exhibits.firstIndex(where: { $0.id == id }) else { return }
        exhibits[idx].objectName = trimmed
        if currentExhibit?.id == id {
            currentExhibit?.objectName = trimmed
        }
        persist()
    }

    /// 进入指定展厅看展品。
    func enterGallery(_ gallery: Gallery, exhibitIndex: Int? = nil) {
        activeGalleryKey = gallery.titleKey
        // 默认看最近一件
        galleryIndex = exhibitIndex ?? max(0, gallery.exhibits.count - 1)
        stage = .gallery
    }

    // MARK: - 持久化

    /// 把当前 exhibits 异步写盘。append 完调一下。
    func persist() {
        let snapshot = exhibits
        Task.detached(priority: .utility) {
            Self.saveSync(snapshot)
        }
    }

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
}

// MARK: - 书名归一化匹配

extension String {
    /// 用于书名匹配的归一化形式：去除空格、常见标点、统一大小写。
    /// 让 "看不见的城市" 和 "看不见的城市 " 和 "《看不见的城市》" 都视为同一本。
    var normalizedTitleKey: String {
        let punctuation: Set<Character> = [
            "《", "》", "「", "」", "『", "』", "【", "】",
            "\"", "'", "\u{201C}", "\u{201D}", "\u{2018}", "\u{2019}",
            "(", ")", "（", "）", "[", "]",
            ":", "：", "—", "-", "_", "·",
            ",", "，", ".", "。",
            "!", "！", "?", "？",
            " ", "\t", "\n"
        ]
        return self
            .filter { !punctuation.contains($0) }
            .lowercased()
    }
}
