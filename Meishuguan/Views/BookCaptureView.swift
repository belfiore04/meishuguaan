import SwiftUI
import UIKit

struct BookCaptureView: View {
    @Environment(SessionState.self) private var session
    @State private var showCamera = true

    var body: some View {
        Color(.systemBackground)
            .ignoresSafeArea()
            .sheet(isPresented: $showCamera, onDismiss: {
                // 用户取消相机
                if session.currentBook == nil {
                    session.stage = .start
                }
            }) {
                CameraPicker(sourceType: .camera) { image in
                    showCamera = false
                    if let image {
                        identify(image)
                    } else {
                        session.stage = .start
                    }
                }
                .ignoresSafeArea()
            }
    }

    private func identify(_ image: UIImage) {
        session.stage = .identifying
        Task {
            do {
                let (title, author, brief) = try await QwenVLClient.shared.identifyBook(from: image)
                let book = Book(title: title, author: author, brief: brief, coverImage: image)
                await MainActor.run {
                    // 不直接进 chatting；先进 confirming 让用户确认是不是这本
                    session.pendingBook = book
                    session.stage = .confirming
                }
            } catch {
                await MainActor.run {
                    session.lastError = error.localizedDescription
                    session.stage = .start
                }
            }
        }
    }
}

struct CameraPicker: UIViewControllerRepresentable {
    let sourceType: UIImagePickerController.SourceType
    let onPick: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(sourceType) ? sourceType : .photoLibrary
        picker.allowsEditing = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onPick: (UIImage?) -> Void
        init(onPick: @escaping (UIImage?) -> Void) { self.onPick = onPick }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            let image = info[.originalImage] as? UIImage
            picker.dismiss(animated: true) { self.onPick(image) }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true) { self.onPick(nil) }
        }
    }
}
