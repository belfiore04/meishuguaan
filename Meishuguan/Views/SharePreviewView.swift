import SwiftUI

/// 分享前的预览：让用户先看到生成的卡片长什么样，再决定保存到相册 / 调起系统分享。
struct SharePreviewView: View {
    @Environment(\.dismiss) private var dismiss
    let image: UIImage

    @State private var showShareSheet: Bool = false
    @State private var showSavedToast: Bool = false
    @State private var savedFailed: Bool = false

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                preview
                actions
            }

            if showSavedToast || savedFailed {
                toast
            }
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: [image])
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

    private var preview: some View {
        Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .padding(.horizontal, 40)
            .padding(.vertical, 12)
            .frame(maxHeight: .infinity)
    }

    private var actions: some View {
        HStack(spacing: 16) {
            actionButton("保存到相册", emphasized: false) {
                save()
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

    private func save() {
        // UIImageWriteToSavedPhotosAlbum 需要 Info.plist 里 NSPhotoLibraryAddUsageDescription。
        // 通过 SavePhotoHelper 拿回调判断成功/失败，再触发 toast。
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

/// 把 UIImageWriteToSavedPhotosAlbum 的 Objective-C callback 包装成 Swift closure。
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
