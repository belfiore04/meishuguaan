import SwiftUI

struct ChatView: View {
    @Environment(SessionState.self) private var session
    @State private var typedText: String = ""
    @State private var sending: Bool = false
    @FocusState private var typeBarFocused: Bool

    let book: Book

    var body: some View {
        ZStack {
            // 点空白处收键盘
            Color(.systemBackground)
                .ignoresSafeArea()
                .onTapGesture { typeBarFocused = false }

            VStack(spacing: 0) {
                topBar
                chatList
                inputArea
            }
        }
        .task {
            // 记录这次阅读的开始时间
            if session.readingStartedAt == nil {
                session.readingStartedAt = Date()
            }
            // AI 主动发首句（仅当对话还没开始时）
            if session.messages.isEmpty {
                session.messages.append(
                    ChatMessage(role: .assistant, text: makeOpeningLine(book: book))
                )
            }
        }
    }

    /// 第一句话——hardcoded template，按 book metadata 选。
    /// 不调 LLM：0 延迟 + 不可能瞎说书的内容。
    /// 同一本书每次进来都是同一句（用 title bytes 作种子），有"AI 还记得你"的体感。
    private func makeOpeningLine(book: Book) -> String {
        // 已读过这本书（已有展厅）→ 续读姿态，明确"接得上"
        if session.findGallery(matchingTitle: book.title) != nil {
            return "接着上次。"
        }
        // 新书：通用陪伴句 + 有作者时加 author hook
        var candidates: [String] = [
            "嗯，翻开吧。",
            "开始吧。",
            "翻开了。",
            "嗯，开始读。",
        ]
        if let author = book.author, !author.isEmpty {
            candidates.append("\(author)。")
            candidates.append("\(author)。\n嗯，开始吧。")
        }
        let seed = book.title.utf8.reduce(0) { $0 + Int($1) }
        return candidates[seed % candidates.count]
    }

    private var topBar: some View {
        HStack {
            Button {
                session.returnToLobby()
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
            .disabled(session.messages.count < 2 || sending)  // 至少要有一轮真实对话
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
        VStack(spacing: 8) {
            // 深入聊聊开关
            HStack {
                Spacer()
                Button {
                    session.deepMode.toggle()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: session.deepMode ? "circle.fill" : "circle")
                            .font(.system(size: 6))
                        Text(session.deepMode ? "深入中 · 结束" : "深入聊聊")
                    }
                    .font(.system(size: 11, design: .serif))
                    .foregroundStyle(session.deepMode ? Color.primary : .secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .overlay(
                        Capsule().stroke(
                            session.deepMode ? Color.primary.opacity(0.4) : Color.primary.opacity(0.2),
                            lineWidth: 0.5
                        )
                    )
                }
                .buttonStyle(.plain)
                .disabled(sending)
            }
            .padding(.horizontal, 20)

            HStack(spacing: 8) {
                TextField("说点什么…", text: $typedText, axis: .vertical)
                    .font(.system(.body, design: .serif))
                    .lineLimit(1...4)
                    .focused($typeBarFocused)
                    // 多行 TextField 回车其实是换行，不是 submit。
                    // 所以不用 .submitLabel(.send)（向上箭头会误导成"按它就发出"）。
                    // 发送靠右边的圆形按钮。
                Button(action: sendText) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundStyle(typedText.isEmpty ? Color.primary.opacity(0.2) : Color.primary)
                }
                .disabled(typedText.isEmpty || sending)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(
                        session.deepMode ? Color.primary.opacity(0.5) : Color.primary.opacity(0.2),
                        lineWidth: 0.5
                    )
            )
            .padding(.horizontal, 20)
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
        let mode: DeepSeekClient.ReplyMode = session.deepMode ? .deep : .normal

        Task {
            do {
                let reply = try await DeepSeekClient.shared.reply(
                    book: book,
                    history: Array(session.messages.dropLast()),
                    userText: text,
                    mode: mode
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
        typeBarFocused = false
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
                .foregroundStyle(Color.primary.opacity(message.role == .user ? 1.0 : 0.85))
                .multilineTextAlignment(.leading)
                .padding(.vertical, 2)
            if message.role == .assistant { Spacer(minLength: 40) }
        }
        .padding(.horizontal, 24)
    }
}
