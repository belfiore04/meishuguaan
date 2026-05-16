import SwiftUI

struct StartView: View {
    @Environment(SessionState.self) private var session
    @State private var pulse: Bool = false
    @State private var showManualEntry: Bool = false
    @State private var showGalleryPicker: Bool = false

    var body: some View {
        VStack(spacing: 60) {
            Spacer()

            VStack(spacing: 8) {
                Text("美书馆")
                    .font(.system(size: 28, weight: .light, design: .serif))
                    .tracking(8)
                Text("MEISHUGUAN")
                    .font(.system(size: 9, weight: .light, design: .serif))
                    .tracking(4)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Button {
                session.stage = .capturing
            } label: {
                Circle()
                    .stroke(.primary.opacity(0.4), lineWidth: 0.5)
                    .frame(width: 96, height: 96)
                    .overlay(
                        Circle()
                            .fill(.primary.opacity(0.04))
                            .scaleEffect(pulse ? 1.0 : 0.85)
                            .opacity(pulse ? 0 : 1)
                            .animation(
                                .easeOut(duration: 2.6).repeatForever(autoreverses: false),
                                value: pulse
                            )
                    )
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .onAppear { pulse = true }

            VStack(spacing: 12) {
                Text("点一下开始读一本书")
                    .font(.system(.footnote, design: .serif))
                    .foregroundStyle(.tertiary)

                secondaryRow
            }

            // 展厅入口：只在已经有展品时出现，点进去默认是最近活跃的那个展厅
            if let latest = session.galleries.first {
                Button {
                    session.enterGallery(latest)
                } label: {
                    Text("去展厅")
                        .font(.system(.footnote, design: .serif))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 8)
                        .overlay(Capsule().stroke(Color.primary.opacity(0.2), lineWidth: 0.5))
                }
                .buttonStyle(.plain)
            } else {
                Color.clear.frame(height: 33)
            }

            Spacer().frame(height: 60)
        }
        .sheet(isPresented: $showManualEntry) {
            ManualBookEntryView()
                .presentationDetents([.large])
        }
        .sheet(isPresented: $showGalleryPicker) {
            GalleryListView(
                title: "继续读一本",
                onSelect: { gallery in
                    showGalleryPicker = false
                    continueReading(gallery: gallery)
                },
                onCancel: { showGalleryPicker = false }
            )
            .presentationDetents([.medium, .large])
            .presentationBackground(.regularMaterial)
        }
    }

    /// 大圆圈下面那行小字次级入口。
    /// 没有任何展厅时只显示「手动填一本」；有展厅时再加「继续读一本」。
    private var secondaryRow: some View {
        HStack(spacing: 14) {
            secondaryButton("手动填一本") {
                showManualEntry = true
            }

            if !session.galleries.isEmpty {
                Text("·")
                    .font(.system(size: 10, design: .serif))
                    .foregroundStyle(.tertiary)

                secondaryButton("继续读一本") {
                    showGalleryPicker = true
                }
            }
        }
    }

    private func secondaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, design: .serif))
                .foregroundStyle(.secondary)
                .tracking(1)
        }
        .buttonStyle(.plain)
    }

    /// "继续读一本"——用户已主动选了书，跳过 confirming 直接进 chatting。
    /// 用 existing gallery 的 book metadata，新展品会自动归到这个展厅。
    private func continueReading(gallery: SessionState.Gallery) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            session.currentBook = gallery.book
            session.pendingBook = nil
            session.messages = []
            session.stage = .chatting
        }
    }
}
