import SwiftUI

/// 左侧滑出的抽屉。覆盖在主内容之上：左边一张纯白卡片，右边是半透明 dim 层。
/// 用法：放在 ZStack 顶层，通过 `isOpen` 控制；外部 dim 区点击会回写 isOpen = false。
struct LeftDrawerView: View {
    @Environment(SessionState.self) private var session
    @Environment(\.colorScheme) private var colorScheme
    @Binding var isOpen: Bool

    /// 用户在抽屉里选了某个展厅。caller 决定下一步。
    var onSelectGallery: (SessionState.Gallery) -> Void
    /// 用户在抽屉里点了「首页」。
    var onSelectHome: () -> Void
    /// 用户在抽屉底部点了「分享美书馆」。
    var onShareMuseum: () -> Void = {}

    private let drawerWidth: CGFloat = 200

    var body: some View {
        ZStack(alignment: .leading) {
            // 右侧 dim — 深色模式下需要更深的 opacity 才有 dim 感
            Color.black
                .opacity(isOpen ? (colorScheme == .dark ? 0.42 : 0.18) : 0)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeOut(duration: 0.25)) { isOpen = false }
                }
                .allowsHitTesting(isOpen)

            // 左侧卡片
            drawer
                .frame(width: drawerWidth)
                .frame(maxHeight: .infinity)
                .background(Color(.systemBackground))
                .offset(x: isOpen ? 0 : -drawerWidth)
        }
        .animation(.easeOut(duration: 0.25), value: isOpen)
    }

    private var drawer: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 顶部留白 + 一个克制的标识
            VStack(alignment: .leading, spacing: 4) {
                Text("美书馆")
                    .font(.system(size: 14, weight: .light, design: .serif))
                    .tracking(4)
                Text("MEISHUGUAN")
                    .font(.system(size: 7, weight: .light, design: .serif))
                    .tracking(2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 20)
            .padding(.top, 56)
            .padding(.bottom, 28)

            Divider().padding(.horizontal, 20)

            // 首页
            Button {
                withAnimation(.easeOut(duration: 0.25)) { isOpen = false }
                onSelectHome()
            } label: {
                row(text: "首页", isCurrent: false)
            }
            .buttonStyle(.plain)

            if !session.galleries.isEmpty {
                Divider().padding(.horizontal, 20)
                    .padding(.top, 4)
            }

            // 展厅列表（可滚）
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(session.galleries) { gallery in
                        Button {
                            withAnimation(.easeOut(duration: 0.25)) { isOpen = false }
                            onSelectGallery(gallery)
                        } label: {
                            row(
                                text: gallery.book.title,
                                isCurrent: gallery.titleKey == session.activeGalleryKey
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 4)
            }

            // 底部分享美书馆
            Divider().padding(.horizontal, 20)
            Button {
                withAnimation(.easeOut(duration: 0.25)) { isOpen = false }
                // 等抽屉关闭后再触发，避免 sheet 和 drawer 冲突
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    onShareMuseum()
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 12, weight: .ultraLight))
                        .foregroundStyle(.secondary)
                    Text("分享美书馆")
                        .font(.system(.footnote, design: .serif))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.bottom, 24)
        }
    }

    private func row(text: String, isCurrent: Bool) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(isCurrent ? Color.primary.opacity(0.6) : Color.clear)
                .frame(width: 4, height: 4)
            Text(text)
                .font(.system(.footnote, design: .serif))
                .foregroundStyle(isCurrent ? Color.primary : Color.primary.opacity(0.7))
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}
