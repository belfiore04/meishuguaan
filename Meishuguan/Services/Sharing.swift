import SwiftUI
import UIKit
import CoreImage.CIFilterBuiltins

// MARK: - QR Code 生成

enum QRCodeGenerator {
    /// 生成黑白 QR 码 UIImage。size 是输出像素尺寸。
    /// v1 占位用 GitHub repo 链接，未来做 deep link 时换 string。
    static func image(from string: String, size: CGFloat = 240) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        let scale = size / output.extent.width
        let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let context = CIContext()
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

// MARK: - 虚线分隔（票根感的核心装饰）

struct DashedLine: View {
    var color: Color = Color.primary.opacity(0.35)
    var dashLength: CGFloat = 3
    var gapLength: CGFloat = 3
    var lineWidth: CGFloat = 0.5

    var body: some View {
        DashedHorizontal()
            .stroke(
                style: StrokeStyle(
                    lineWidth: lineWidth,
                    lineCap: .butt,
                    dash: [dashLength, gapLength]
                )
            )
            .foregroundStyle(color)
            .frame(height: lineWidth)
    }
}

private struct DashedHorizontal: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}

// MARK: - ImageRenderer 包装

enum ShareRenderer {
    /// 把任意 SwiftUI View 渲染成 1080×1920 的 9:16 竖图。
    @MainActor
    static func render<Content: View>(_ content: Content) -> UIImage? {
        let size = CGSize(width: 1080, height: 1920)
        let renderer = ImageRenderer(
            content: content
                .frame(width: size.width, height: size.height)
                .background(Color(.systemBackground))
        )
        renderer.scale = 1.0    // content 已经按 1080×1920 真实尺寸排版
        renderer.proposedSize = ProposedViewSize(size)
        return renderer.uiImage
    }
}

// MARK: - 系统分享面板

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
