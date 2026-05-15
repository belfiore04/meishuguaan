import SwiftUI

/// 展厅页：一本书的所有展品左右滑切换。
/// activeGalleryKey 控制看的是哪个展厅；galleryIndex 控制看到这个展厅里第几件。
struct ExhibitGalleryView: View {
    @Environment(SessionState.self) private var session
    @State private var showNote: Bool = false
    @State private var drawerOpen: Bool = false
    @State private var showShareDialog: Bool = false
    @State private var shareMode: ShareMode?

    var body: some View {
        ZStack(alignment: .leading) {
            // 主内容
            ZStack {
                Color(.systemBackground).ignoresSafeArea()

                VStack(spacing: 0) {
                    topBar
                    if let gallery = session.activeGallery, !gallery.exhibits.isEmpty {
                        pager(gallery: gallery)
                        bottomBar(gallery: gallery)
                    } else {
                        emptyState
                    }
                }
            }

            // 抽屉浮层
            LeftDrawerView(
                isOpen: $drawerOpen,
                onSelectGallery: { gallery in
                    session.enterGallery(gallery)
                },
                onSelectHome: {
                    session.returnToLobby()
                },
                onShareMuseum: {
                    shareMuseum()
                }
            )
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
        .confirmationDialog("", isPresented: $showShareDialog, titleVisibility: .hidden) {
            Button("分享此展品") {
                if let ex = currentExhibit { shareMode = .exhibit(ex) }
            }
            Button("分享此展厅") {
                if let g = session.activeGallery { shareMode = .gallery(g) }
            }
            Button("分享美书馆") {
                shareMode = .museum(session.galleries)
            }
            Button("取消", role: .cancel) {}
        }
        .sheet(item: $shareMode) { mode in
            SharePreviewView(mode: mode)
        }
    }

    // MARK: - 分享美书馆（从抽屉触发）
    private func shareMuseum() {
        shareMode = .museum(session.galleries)
    }

    private var currentExhibit: Exhibit? {
        guard let gallery = session.activeGallery else { return nil }
        guard gallery.exhibits.indices.contains(session.galleryIndex) else { return nil }
        return gallery.exhibits[session.galleryIndex]
    }

    private var topBar: some View {
        HStack {
            // 左：汉堡（开抽屉）
            Button {
                withAnimation(.easeOut(duration: 0.25)) {
                    drawerOpen = true
                }
            } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 16, weight: .light))
                    .foregroundStyle(.secondary)
                    .padding(8)
            }

            Spacer()

            // 中：当前展厅书名 + 位置
            VStack(spacing: 2) {
                if let gallery = session.activeGallery {
                    Text(gallery.book.title)
                        .font(.system(.subheadline, design: .serif))
                        .lineLimit(1)
                    if !gallery.exhibits.isEmpty {
                        Text("\(session.galleryIndex + 1) / \(gallery.exhibits.count)")
                            .font(.system(size: 10, design: .serif))
                            .foregroundStyle(.tertiary)
                    }
                } else {
                    Text("展厅").font(.system(.subheadline, design: .serif))
                }
            }

            Spacer()

            // 右：分享
            Button {
                showShareDialog = true
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 16, weight: .light))
                    .foregroundStyle(.secondary)
                    .padding(8)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }

    private func pager(gallery: SessionState.Gallery) -> some View {
        TabView(selection: Binding(
            get: { session.galleryIndex },
            set: { session.galleryIndex = $0 }
        )) {
            ForEach(Array(gallery.exhibits.enumerated()), id: \.element.id) { idx, exhibit in
                ExhibitStage(exhibit: exhibit)
                    .tag(idx)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
    }

    private func bottomBar(gallery: SessionState.Gallery) -> some View {
        VStack(spacing: 8) {
            if let exhibit = currentExhibit {
                Text(exhibit.objectName)
                    .font(.system(size: 22, weight: .light, design: .serif))
                    .tracking(4)
                    .padding(.bottom, 2)

                if let author = gallery.book.author {
                    Text(author)
                        .font(.system(size: 11, design: .serif))
                        .foregroundStyle(.tertiary)
                }

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
                        .overlay(Capsule().stroke(Color.primary.opacity(0.2), lineWidth: 0.5))
                }
                .padding(.top, 14)
            }
        }
        .padding(.bottom, 36)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Text("这个展厅还没有展品")
                .font(.system(.footnote, design: .serif))
                .foregroundStyle(.tertiary)
            Spacer()
        }
    }
}
