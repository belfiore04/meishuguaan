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
    var exhibits: [Exhibit] = []     // 这次 app 会话里积累的展品
    var galleryIndex: Int = 0        // 展厅当前看到第几件
    var lastError: String?

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
