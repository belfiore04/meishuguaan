import SwiftUI

/// 分享前的预览。接 ShareMode：
/// - exhibit：直接渲染，无 LLM 调用。
/// - gallery：先调 DeepSeek 生成展厅引言 → 再渲染。
/// - museum：先调 DeepSeek 生成开门致辞 → 再渲染。
struct SharePreviewView: View {
    @Environment(\.dismiss) private var dismiss
    let mode: ShareMode

    @State private var image: UIImage?
    @State private var loadingText: String = "正在为你准备一张卡片…"
    @State private var failed: Bool = false
    @State private var showShareSheet: Bool = false
    @State private var showSavedToast: Bool = false
    @State private var savedFailed: Bool = false

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                if let image {
                    preview(image: image)
                    actions(image: image)
                } else if failed {
                    failedView
                } else {
                    loadingView
                }
            }

            if showSavedToast || savedFailed {
                toast
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let image {
                ShareSheet(items: [image])
            }
        }
        .task {
            await generate()
        }
    }

    private var topBar: some View {
        HStack {
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .light))
                    .foregroundStyle(.secondary)
                    .padding(12)
            }
        }
        .padding(.top, 8)
        .padding(.horizontal, 8)
    }

    private func preview(image: UIImage) -> some View {
        Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .padding(.horizontal, 40)
            .padding(.vertical, 12)
            .frame(maxHeight: .infinity)
    }

    private func actions(image: UIImage) -> some View {
        HStack(spacing: 16) {
            actionButton("保存到相册", emphasized: false) {
                save(image: image)
            }
            actionButton("分享", emphasized: true) {
                showShareSheet = true
            }
        }
        .padding(.horizontal, 40)
        .padding(.bottom, 40)
    }

    private func actionButton(_ title: String, emphasized: Bool, action: @escaping () -> Void) -> some View {
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

    private var loadingView: some View {
        VStack(spacing: 24) {
            Spacer()
            ProgressView()
                .controlSize(.large)
                .tint(.primary)
            Text(loadingText)
                .font(.system(.callout, design: .serif))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
    }

    private var failedView: some View {
        VStack(spacing: 16) {
            Spacer()
            Text("生成失败")
                .font(.system(.body, design: .serif))
                .foregroundStyle(.secondary)
            Button("重试") {
                Task { await generate() }
            }
            .font(.system(.footnote, design: .serif))
            .foregroundStyle(.primary)
            Spacer()
        }
    }

    private var toast: some View {
        VStack {
            Spacer()
            Text(savedFailed ? "保存失败，请允许相册权限" : "已保存到相册")
                .font(.system(.footnote, design: .serif))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(.regularMaterial, in: Capsule())
                .padding(.bottom, 130)
        }
        .transition(.opacity)
    }

    // MARK: - 生成

    private func generate() async {
        failed = false
        switch mode {
        case .exhibit(let exhibit):
            await MainActor.run {
                loadingText = "正在准备这件展品…"
            }
            let img = await MainActor.run {
                ShareRenderer.render(ExhibitShareCard(exhibit: exhibit))
            }
            await MainActor.run {
                if let img { image = img } else { failed = true }
            }

        case .gallery(let gallery):
            await MainActor.run {
                loadingText = "正在为这个展厅写一段引言…"
            }
            let exhibitsData = gallery.exhibits.map {
                (objectName: $0.objectName, noteText: $0.noteText)
            }
            let intro = (try? await DeepSeekClient.shared.generateGalleryIntro(
                bookTitle: gallery.book.title,
                exhibits: exhibitsData
            )) ?? ""
            let img = await MainActor.run {
                ShareRenderer.render(GalleryShareCard(gallery: gallery, intro: intro))
            }
            await MainActor.run {
                if let img { image = img } else { failed = true }
            }

        case .museum(let galleries):
            await MainActor.run {
                loadingText = "正在为美书馆写一段开门致辞…"
            }
            let galleriesData = galleries.map {
                (bookTitle: $0.book.title, objectNames: $0.exhibits.map(\.objectName))
            }
            let intro = (try? await DeepSeekClient.shared.generateMuseumIntro(
                galleries: galleriesData
            )) ?? ""
            let img = await MainActor.run {
                ShareRenderer.render(MuseumShareCard(galleries: galleries, intro: intro))
            }
            await MainActor.run {
                if let img { image = img } else { failed = true }
            }
        }
    }

    // MARK: - 保存到相册

    private func save(image: UIImage) {
        SavePhotoHelper.shared.save(image: image) { error in
            DispatchQueue.main.async {
                if error == nil {
                    withAnimation { showSavedToast = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation { showSavedToast = false }
                    }
                } else {
                    withAnimation { savedFailed = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        withAnimation { savedFailed = false }
                    }
                }
            }
        }
    }
}

/// 把 UIImageWriteToSavedPhotosAlbum 的 Objective-C 回调包装成 Swift closure。
final class SavePhotoHelper: NSObject {
    static let shared = SavePhotoHelper()
    private var onFinish: ((Error?) -> Void)?

    func save(image: UIImage, completion: @escaping (Error?) -> Void) {
        self.onFinish = completion
        UIImageWriteToSavedPhotosAlbum(
            image,
            self,
            #selector(image(_:didFinishSavingWithError:contextInfo:)),
            nil
        )
    }

    @objc private func image(_ image: UIImage,
                             didFinishSavingWithError error: Error?,
                             contextInfo: UnsafeRawPointer) {
        onFinish?(error)
        onFinish = nil
    }
}
