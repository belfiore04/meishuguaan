import SwiftUI

/// 手动填一本书：电子书 / 听书 / 拍照识别失败时的兜底入口。
/// 提交后走和拍照后一样的 ConfirmBookView 流程——
/// 如果归一化后的书名能 match 上已有展厅，会自动提示"你正在继续读"。
struct ManualBookEntryView: View {
    @Environment(SessionState.self) private var session
    @Environment(\.dismiss) private var dismiss

    @State private var title: String = ""
    @State private var author: String = ""
    @State private var brief: String = ""
    @FocusState private var focused: Field?

    private enum Field { case title, author, brief }

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        heading
                        field(label: "书名", text: $title, placeholder: "必填", focus: .title)
                        field(label: "作者", text: $author, placeholder: "可不填", focus: .author)
                        field(label: "一句话简介", text: $brief, placeholder: "可不填，帮 AI 更懂这本书", focus: .brief, multiline: true)
                    }
                    .padding(.horizontal, 32)
                    .padding(.top, 24)
                }
                bottomAction
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                focused = .title
            }
        }
    }

    // MARK: - 顶部

    private var topBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .light))
                    .foregroundStyle(.secondary)
                    .padding(12)
            }
            Spacer()
        }
        .padding(.top, 4)
        .padding(.horizontal, 8)
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("手动登记一本")
                .font(.system(size: 11, design: .serif))
                .foregroundStyle(.tertiary)
                .tracking(2)
            Text("不在手边也没关系")
                .font(.system(size: 24, weight: .light, design: .serif))
                .tracking(1)
        }
    }

    // MARK: - 单个字段

    private func field(label: String, text: Binding<String>, placeholder: String, focus: Field, multiline: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 11, design: .serif))
                .foregroundStyle(.tertiary)
                .tracking(2)

            if multiline {
                TextField(placeholder, text: text, axis: .vertical)
                    .lineLimit(2...5)
                    .font(.system(.body, design: .serif))
                    .focused($focused, equals: focus)
            } else {
                TextField(placeholder, text: text)
                    .font(.system(.body, design: .serif))
                    .focused($focused, equals: focus)
                    .submitLabel(focus == .title ? .next : .done)
                    .onSubmit {
                        if focus == .title { focused = .author }
                        else if focus == .author { focused = .brief }
                        else { focused = nil }
                    }
            }

            Rectangle()
                .fill(Color.primary.opacity(0.15))
                .frame(height: 0.5)
        }
    }

    // MARK: - 底部按钮

    private var bottomAction: some View {
        Button(action: submit) {
            Text("开始读这本书")
                .font(.system(.body, design: .serif))
                .foregroundStyle(canSubmit ? Color.primary : Color.primary.opacity(0.3))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .overlay(
                    Capsule().stroke(
                        canSubmit ? Color.primary.opacity(0.5) : Color.primary.opacity(0.15),
                        lineWidth: 0.5
                    )
                )
        }
        .buttonStyle(.plain)
        .disabled(!canSubmit)
        .padding(.horizontal, 40)
        .padding(.bottom, 36)
    }

    private var canSubmit: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func submit() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }
        let trimmedAuthor = author.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBrief = brief.trimmingCharacters(in: .whitespacesAndNewlines)
        let book = Book(
            title: trimmedTitle,
            author: trimmedAuthor.isEmpty ? nil : trimmedAuthor,
            brief: trimmedBrief
        )
        session.pendingBook = book
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            session.stage = .confirming
        }
    }
}
