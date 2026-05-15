import SwiftUI

/// 展厅列表。双用途：
/// 1. 汉堡菜单的 sheet——让用户切换展厅。
/// 2. ConfirmBookView "这不是一本新书" 后的 picker——让用户从已有展厅里挑。
struct GalleryListView: View {
    @Environment(SessionState.self) private var session

    var title: String = "展厅"
    /// 用户选中某个展厅时调。caller 决定下一步（切换 / 进入 confirm 流程）。
    var onSelect: (SessionState.Gallery) -> Void
    /// 用户取消（点 sheet 外或 cancel 按钮）。
    var onCancel: () -> Void = {}

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 11, design: .serif))
                        .foregroundStyle(.tertiary)
                        .tracking(2)
                    Text("共 \(session.galleries.count) 个展厅")
                        .font(.system(.footnote, design: .serif))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 28)
                .padding(.top, 32)
                .padding(.bottom, 18)

                Divider().padding(.horizontal, 28)

                ForEach(session.galleries) { gallery in
                    Button {
                        onSelect(gallery)
                    } label: {
                        GalleryRow(gallery: gallery)
                    }
                    .buttonStyle(.plain)
                    Divider().padding(.horizontal, 28)
                }

                Spacer(minLength: 36)
            }
        }
    }
}

private struct GalleryRow: View {
    let gallery: SessionState.Gallery

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(gallery.book.title)
                .font(.system(.body, design: .serif))
                .foregroundStyle(.primary)

            HStack(spacing: 8) {
                if let author = gallery.book.author {
                    Text(author)
                        .font(.system(size: 11, design: .serif))
                        .foregroundStyle(.tertiary)
                }
                Text("·")
                    .font(.system(size: 11, design: .serif))
                    .foregroundStyle(.tertiary)
                Text("\(gallery.exhibits.count) 件展品")
                    .font(.system(size: 11, design: .serif))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 28)
        .padding(.vertical, 16)
        .contentShape(Rectangle())
    }
}
