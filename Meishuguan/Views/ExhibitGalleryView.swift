import SwiftUI

struct ExhibitGalleryView: View {
    @Environment(SessionState.self) private var session
    @State private var showNote: Bool = false
    @State private var showMenu: Bool = false

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                pager
                bottomBar
            }
        }
        .sheet(isPresented: $showNote) {
            if let exhibit = currentExhibit {
                ExhibitLabelView(exhibit: exhibit) { newName in
                    session.renameExhibit(id: exhibit.id, to: newName)
                }
                .presentationDetents([.medium, .large])
                .presentationBackground(.regularMaterial)
            }
        }
        .confirmationDialog("", isPresented: $showMenu, titleVisibility: .hidden) {
            Button("回主页") { session.returnToLobby() }
            // 展馆列表（多书层级做完后启用）
            Button("取消", role: .cancel) { }
        }
    }

    private var currentExhibit: Exhibit? {
        guard session.exhibits.indices.contains(session.galleryIndex) else { return nil }
        return session.exhibits[session.galleryIndex]
    }

    private var topBar: some View {
        HStack {
            Button {
                showMenu = true
            } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 16, weight: .light))
                    .foregroundStyle(.secondary)
                    .padding(8)
            }
            Spacer()
            VStack(spacing: 2) {
                Text("展厅")
                    .font(.system(.subheadline, design: .serif))
                Text("\(session.galleryIndex + 1) / \(session.exhibits.count)")
                    .font(.system(size: 10, design: .serif))
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            Color.clear.frame(width: 32, height: 32)
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }

    private var pager: some View {
        TabView(selection: Binding(
            get: { session.galleryIndex },
            set: { session.galleryIndex = $0 }
        )) {
            ForEach(Array(session.exhibits.enumerated()), id: \.element.id) { idx, exhibit in
                ExhibitStage(exhibit: exhibit)
                    .tag(idx)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
    }

    private var bottomBar: some View {
        VStack(spacing: 8) {
            if let exhibit = currentExhibit {
                Text(exhibit.objectName)
                    .font(.system(size: 22, weight: .light, design: .serif))
                    .tracking(4)
                    .padding(.bottom, 2)

                Text(exhibit.book.title + (exhibit.book.author.map { " · \($0)" } ?? ""))
                    .font(.system(size: 11, design: .serif))
                    .foregroundStyle(.tertiary)

                Text(ExhibitTimeFormatter.string(start: exhibit.startedAt, end: exhibit.generatedAt))
                    .font(.system(size: 10, design: .serif))
                    .foregroundStyle(.tertiary)
                    .tracking(1)
                    .padding(.top, 2)

                Button {
                    showNote = true
                } label: {
                    Text("展台说明")
                        .font(.system(.footnote, design: .serif))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 8)
                        .overlay(Capsule().stroke(.tertiary, lineWidth: 0.5))
                }
                .padding(.top, 14)
            }
        }
        .padding(.bottom, 36)
    }
}
