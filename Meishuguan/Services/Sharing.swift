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
    /// 分享卡始终是纯白底 + 黑字（票根/明信片美学），不跟随系统深色模式——
    /// 通过 .environment(\.colorScheme, .light) 强制内部所有 semantic 颜色用亮色 token。
    @MainActor
    static func render<Content: View>(_ content: Content) -> UIImage? {
        let size = CGSize(width: 1080, height: 1920)
        let renderer = ImageRenderer(
            content: content
                .frame(width: size.width, height: size.height)
                .background(Color.white)
                .environment(\.colorScheme, .light)
        )
        renderer.scale = 1.0
        renderer.proposedSize = ProposedViewSize(size)
        return renderer.uiImage
    }
}

// MARK: - 分享对象

/// 三种分享层级。给 SharePreviewView 当 sheet item 用。
enum ShareMode: Identifiable {
    case exhibit(Exhibit)
    case gallery(SessionState.Gallery)
    case museum([SessionState.Gallery])

    var id: String {
        switch self {
        case .exhibit(let e): return "e-\(e.id.uuidString)"
        case .gallery(let g): return "g-\(g.titleKey)"
        case .museum: return "m-all"
        }
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
