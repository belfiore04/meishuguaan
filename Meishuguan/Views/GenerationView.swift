import SwiftUI

struct GenerationView: View {
    @Environment(SessionState.self) private var session
    @State private var started = false

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            VStack(spacing: 36) {
                Spacer()
                BreathingCircle(progress: session.generationProgress)
                Text(session.generationStatusText.isEmpty ? "AI 正在为这次阅读做一件物件" : session.generationStatusText)
                    .font(.system(.callout, design: .serif))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                Spacer()
                Text("这可能要等几分钟。慢慢呼吸。")
                    .font(.system(size: 11, design: .serif))
                    .foregroundStyle(.tertiary)
                Spacer().frame(height: 60)
            }
        }
        .task {
            guard !started else { return }
            started = true
            await run()
        }
    }

    private func run() async {
        guard let book = session.currentBook else {
            session.stage = .start
            return
        }
        do {
            await MainActor.run {
                session.generationProgress = 0
                session.generationStatusText = "AI 正在整理这次的笔记…"
            }
            let summary = try await DeepSeekClient.shared.summarize(book: book, messages: session.messages)

            await MainActor.run {
                session.generationStatusText = "正在为「\(summary.objectName)」塑形…"
            }

            let imageURL = try await ImageGenerationClient.shared.generateImage(prompt: summary.objectPrompt) { p, msg in
                Task { @MainActor in
                    session.generationProgress = p
                    session.generationStatusText = msg
                }
            }

            let exhibit = Exhibit(
                book: book,
                noteText: summary.note,
                objectPrompt: summary.objectPrompt,
                imageLocalURL: imageURL
            )
            await MainActor.run {
                session.currentExhibit = exhibit
                session.stage = .showingExhibit
            }
        } catch {
            await MainActor.run {
                session.lastError = error.localizedDescription
                session.stage = .chatting
            }
        }
    }
}

private struct BreathingCircle: View {
    var progress: Double
    @State private var phase: Double = 0

    var body: some View {
        ZStack {
            Circle()
                .stroke(.tertiary, lineWidth: 0.5)
                .frame(width: 140, height: 140)
                .scaleEffect(1.0 + 0.04 * sin(phase))
            Circle()
                .trim(from: 0, to: max(0.02, min(1.0, progress)))
                .stroke(.primary.opacity(0.6), style: StrokeStyle(lineWidth: 1, lineCap: .round))
                .frame(width: 140, height: 140)
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.6), value: progress)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
                phase = .pi * 2
            }
        }
    }
}
