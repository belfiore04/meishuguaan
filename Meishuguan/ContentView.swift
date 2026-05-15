import SwiftUI

struct ContentView: View {
    @Environment(SessionState.self) private var session

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            switch session.stage {
            case .start:
                StartView()
            case .capturing:
                BookCaptureView()
            case .identifying:
                IdentifyingView()
            case .confirming:
                ConfirmBookView()
            case .chatting:
                if let book = session.currentBook {
                    ChatView(book: book)
                }
            case .generating:
                GenerationView()
            case .showingExhibit:
                if let exhibit = session.currentExhibit {
                    ExhibitView(exhibit: exhibit)
                }
            case .gallery:
                ExhibitGalleryView()
            }

            if let err = session.lastError {
                ErrorBanner(message: err) {
                    session.lastError = nil
                }
            }
        }
        .animation(.easeInOut(duration: 0.4), value: session.stage)
    }
}

private struct ErrorBanner: View {
    let message: String
    let dismiss: () -> Void

    var body: some View {
        VStack {
            HStack(alignment: .top, spacing: 12) {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                Spacer()
                Button(action: dismiss) {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(14)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .padding(.horizontal, 20)
            .padding(.top, 50)
            Spacer()
        }
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

private struct IdentifyingView: View {
    var body: some View {
        VStack(spacing: 20) {
            ProgressView().controlSize(.large).tint(.primary)
            Text("正在认这本书…")
                .font(.system(.body, design: .serif))
                .foregroundStyle(.secondary)
        }
    }
}
