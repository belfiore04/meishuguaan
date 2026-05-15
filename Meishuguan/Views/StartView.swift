import SwiftUI

struct StartView: View {
    @Environment(SessionState.self) private var session
    @State private var pulse: Bool = false

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

            Text("点一下开始读一本书")
                .font(.system(.footnote, design: .serif))
                .foregroundStyle(.tertiary)

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
    }
}
