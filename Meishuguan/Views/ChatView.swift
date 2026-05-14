import SwiftUI

struct ChatView: View {
    @Environment(SessionState.self) private var session
    @State private var speech = SpeechRecognizer()
    @State private var typedText: String = ""
    @State private var sending: Bool = false
    @State private var showTypeBar: Bool = false
    @FocusState private var typeBarFocused: Bool

    let book: Book

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                chatList
                inputArea
            }
        }
        .task {
            _ = await speech.requestAuthorization()
        }
    }

    private var topBar: some View {
        HStack {
            Button {
                session.stage = .start
                session.reset()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .light))
                    .foregroundStyle(.secondary)
                    .padding(8)
            }
            Spacer()
            VStack(spacing: 2) {
                Text(book.title)
                    .font(.system(.subheadline, design: .serif))
                    .lineLimit(1)
                if let author = book.author {
                    Text(author)
                        .font(.system(size: 10, design: .serif))
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer()
            Button {
                end()
            } label: {
                Text("收尾")
                    .font(.system(.footnote, design: .serif))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .overlay(
                        Capsule().stroke(.tertiary, lineWidth: 0.5)
                    )
            }
            .disabled(session.messages.isEmpty || sending)
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 12)
    }

    private var chatList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 24) {
                    ForEach(session.messages) { msg in
                        MessageBubble(message: msg)
                            .id(msg.id)
                    }
                    if sending {
                        HStack { ProgressView().controlSize(.mini); Spacer() }
                            .padding(.horizontal, 24)
                    }
                }
                .padding(.vertical, 24)
            }
            .onChange(of: session.messages.count) { _, _ in
                if let last = session.messages.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
    }

    private var inputArea: some View {
        VStack(spacing: 12) {
            if showTypeBar {
                HStack(spacing: 8) {
                    TextField("说点什么…", text: $typedText, axis: .vertical)
                        .font(.system(.body, design: .serif))
                        .lineLimit(1...4)
                        .focused($typeBarFocused)
                        .submitLabel(.send)
                        .onSubmit { sendText() }
                    Button(action: sendText) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                            .foregroundStyle(typedText.isEmpty ? .tertiary : .primary)
                    }
                    .disabled(typedText.isEmpty || sending)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(.tertiary, lineWidth: 0.5)
                )
                .padding(.horizontal, 20)
            }

            HStack(spacing: 24) {
                Spacer()
                Button {
                    showTypeBar.toggle()
                    if showTypeBar { typeBarFocused = true }
                } label: {
                    Image(systemName: showTypeBar ? "mic" : "keyboard")
                        .font(.system(size: 18, weight: .light))
                        .foregroundStyle(.secondary)
                        .frame(width: 36, height: 36)
                }
                .disabled(sending)

                MicButton(speech: speech) { transcript in
                    if !transcript.isEmpty {
                        send(text: transcript)
                    }
                }
                .disabled(sending)

                Color.clear.frame(width: 36, height: 36)
                Spacer()
            }
        }
        .padding(.bottom, 24)
    }

    private func sendText() {
        let text = typedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        typedText = ""
        send(text: text)
    }

    private func send(text: String) {
        let userMsg = ChatMessage(role: .user, text: text)
        session.messages.append(userMsg)
        sending = true

        Task {
            do {
                let reply = try await DeepSeekClient.shared.reply(
                    book: book,
                    history: Array(session.messages.dropLast()),
                    userText: text
                )
                await MainActor.run {
                    session.messages.append(ChatMessage(role: .assistant, text: reply))
                    sending = false
                }
            } catch {
                await MainActor.run {
                    session.lastError = error.localizedDescription
                    sending = false
                }
            }
        }
    }

    private func end() {
        session.stage = .generating
    }
}

private struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 40) }
            Text(message.text)
                .font(.system(.body, design: .serif))
                .foregroundStyle(message.role == .user ? .primary : .primary.opacity(0.85))
                .multilineTextAlignment(.leading)
                .padding(.vertical, 2)
            if message.role == .assistant { Spacer(minLength: 40) }
        }
        .padding(.horizontal, 24)
    }
}

private struct MicButton: View {
    @Bindable var speech: SpeechRecognizer
    let onFinish: (String) -> Void

    var body: some View {
        Circle()
            .stroke(.primary.opacity(speech.isRecording ? 0.6 : 0.3), lineWidth: 0.5)
            .background(
                Circle().fill(.primary.opacity(speech.isRecording ? 0.08 : 0.0))
            )
            .frame(width: 80, height: 80)
            .overlay(
                Image(systemName: "circle.fill")
                    .font(.system(size: 6))
                    .foregroundStyle(speech.isRecording ? .primary : .clear)
            )
            .scaleEffect(speech.isRecording ? 1.05 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: speech.isRecording)
            .gesture(
                LongPressGesture(minimumDuration: 0.1)
                    .onChanged { _ in
                        if !speech.isRecording { speech.startRecording() }
                    }
                    .onEnded { _ in
                        let t = speech.transcript
                        speech.stopRecording()
                        onFinish(t)
                    }
            )
    }
}
