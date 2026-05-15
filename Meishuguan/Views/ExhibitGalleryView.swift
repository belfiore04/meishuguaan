import SwiftUI

struct ExhibitGalleryView: View {
    @Environment(SessionState.self) private var session
    @State private var showNote: Bool = false

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                pager
            }
        }
        .sheet(isPresented: $showNote) {
            if let exhibit = currentExhibit {
                NotePaperView(noteText: exhibit.noteText, book: exhibit.book)
                    .presentationDetents([.medium, .large])
                    .presentationBackground(.regularMaterial)
            }
        }
    }

    private var currentExhibit: Exhibit? {
        guard session.exhibits.indices.contains(session.galleryIndex) else { return nil }
        return session.exhibits[session.galleryIndex]
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
                ExhibitPage(exhibit: exhibit, onTapNote: { showNote = true })
                    .tag(idx)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
    }
}

private struct ExhibitPage: View {
    let exhibit: Exhibit
    let onTapNote: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                if let url = exhibit.imageLocalURL,
                   let img = UIImage(contentsOfFile: url.path) {
                    Image(uiImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding(40)
                } else if let url = exhibit.modelLocalURL {
                    ModelStageView(modelURL: url)
                } else if let symbol = exhibit.fallbackSymbol {
                    Image(systemName: symbol)
                        .font(.system(size: 96, weight: .ultraLight))
                        .foregroundStyle(.primary.opacity(0.75))
                } else {
                    Text("展品文件丢失")
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(maxHeight: .infinity)

            VStack(spacing: 8) {
                Text(exhibit.book.title)
                    .font(.system(.subheadline, design: .serif))
                if let author = exhibit.book.author {
                    Text(author)
                        .font(.system(size: 10, design: .serif))
                        .foregroundStyle(.tertiary)
                }
                Button {
                    onTapNote()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "doc.plaintext")
                            .font(.caption)
                        Text("展台说明")
                            .font(.system(.footnote, design: .serif))
                    }
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .overlay(Capsule().stroke(.tertiary, lineWidth: 0.5))
                }
                .padding(.top, 4)
            }
            .padding(.bottom, 48)
        }
    }
}
