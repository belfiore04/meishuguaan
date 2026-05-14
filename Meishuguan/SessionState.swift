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
    }

    var stage: Stage = .start
    var currentBook: Book?
    var messages: [ChatMessage] = []
    var generationProgress: Double = 0
    var generationStatusText: String = ""
    var currentExhibit: Exhibit?
    var lastError: String?

    func reset() {
        stage = .start
        currentBook = nil
        messages = []
        generationProgress = 0
        generationStatusText = ""
        currentExhibit = nil
        lastError = nil
    }
}
