import SwiftUI

/// 拍完书后让用户确认这是不是识别出来的书。
/// 两种情况：
/// - 识别为已有展厅 → 「没错」继续读 / 「这是一本新书」当新书处理
/// - 识别为新书 → 「这是一本新书」开始 / 「这不是一本新书」→ 弹已有展厅列表让用户选
struct ConfirmBookView: View {
    @Environment(SessionState.self) private var session
    @State private var showPicker: Bool = false

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                content
                bottomActions
            }
        }
        .sheet(isPresented: $showPicker) {
            GalleryListView(
                title: "从已有展厅里选",
                onSelect: { gallery in
                    showPicker = false
                    proceedAsExisting(gallery: gallery)
                },
                onCancel: { showPicker = false }
            )
            .presentationDetents([.medium, .large])
            .presentationBackground(.regularMaterial)
        }
    }

    // MARK: - 顶部

    private var topBar: some View {
        HStack {
            Button {
                session.pendingBook = nil
                session.stage = .start
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .light))
                    .foregroundStyle(.secondary)
                    .padding(8)
            }
            Spacer()
            Color.clear.frame(width: 32, height: 32)
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }

    // MARK: - 中间内容（书的信息）

    private var content: some View {
        VStack(spacing: 24) {
            Spacer()

            if let book = session.pendingBook {
                VStack(spacing: 10) {
                    Text(headingText)
                        .font(.system(size: 11, design: .serif))
                        .foregroundStyle(.tertiary)
                        .tracking(2)

                    Text(book.title)
                        .font(.system(size: 26, weight: .light, design: .serif))
                        .tracking(2)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)

                    if let author = book.author {
                        Text(author)
                            .font(.system(.footnote, design: .serif))
                            .foregroundStyle(.secondary)
                    }
                }

                if !book.brief.isEmpty {
                    Text(book.brief)
                        .font(.system(.footnote, design: .serif))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 36)
                        .padding(.top, 6)
                }
            }

            Spacer()
        }
    }

    /// 上方那条提示语，根据是否同书变化。
    private var headingText: String {
        if let book = session.pendingBook, session.findGallery(matchingTitle: book.title) != nil {
            return "看起来你正在继续读"
        }
        return "看起来这是一本新书"
    }

    // MARK: - 底部按钮

    private var bottomActions: some View {
        VStack(spacing: 12) {
            if let book = session.pendingBook,
               let existing = session.findGallery(matchingTitle: book.title) {
                // 识别为已有展厅
                pillButton("没错") {
                    proceedAsExisting(gallery: existing)
                }
                pillButton("这是一本新书", emphasized: false) {
                    proceedAsNew()
                }
            } else {
                // 识别为新书
                pillButton("这是一本新书") {
                    proceedAsNew()
                }
                pillButton("这不是一本新书", emphasized: false) {
                    showPicker = true
                }
            }
        }
        .padding(.horizontal, 40)
        .padding(.bottom, 36)
    }

    private func pillButton(_ title: String, emphasized: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(.body, design: .serif))
                .foregroundStyle(emphasized ? Color.primary : .secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .overlay(
                    Capsule().stroke(
                        emphasized ? Color.primary.opacity(0.5) : Color.primary.opacity(0.2),
                        lineWidth: 0.5
                    )
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - 流程

    /// 用户确认是新书 → 用 pendingBook 进入阅读。
    private func proceedAsNew() {
        guard let book = session.pendingBook else { return }
        session.currentBook = book
        session.pendingBook = nil
        session.messages = []
        session.stage = .chatting
    }

    /// 用户确认是已有展厅 → 用现有展厅的 book metadata 进入阅读
    /// （这样 normalized title key 一致，新展品会自动归到这个展厅）。
    private func proceedAsExisting(gallery: SessionState.Gallery) {
        // 用 existing 的 book 信息，但保留这次拍的封面图
        var book = gallery.book
        book.coverImage = session.pendingBook?.coverImage
        session.currentBook = book
        session.pendingBook = nil
        session.messages = []
        session.stage = .chatting
    }
}
