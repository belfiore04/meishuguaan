import SwiftUI

// MARK: - 1080×1920 9:16 三种分享卡片
//
// 视觉守同一套 token：纯白底、serif、ultraLight/Light 字重、
// tracking 大、灰阶分层；用虚线分区做票根感；右下二维码占位。
//
// 字号是按 1080pt 宽布局设的（不是 iPhone 屏幕物理 pt），
// ImageRenderer 直接渲染。

// MARK: - 展品卡

struct ExhibitShareCard: View {
    let exhibit: Exhibit

    var body: some View {
        VStack(spacing: 0) {
            header
            mainContent
            Spacer(minLength: 0)
            ticketStub
        }
        .padding(.horizontal, 100)
        .padding(.vertical, 90)
        .frame(width: 1080, height: 1920)
        .background(Color(.systemBackground))
    }

    private var header: some View {
        VStack(spacing: 10) {
            Text("美 书 馆 · 展 品")
                .font(.system(size: 32, weight: .light, design: .serif))
                .tracking(8)
            Text("MEISHUGUAN · EXHIBIT")
                .font(.system(size: 12, weight: .ultraLight, design: .serif))
                .tracking(4)
                .foregroundStyle(.tertiary)
        }
    }

    private var mainContent: some View {
        VStack(spacing: 56) {
            DashedLine()
                .padding(.top, 60)

            // 展品视觉
            exhibitVisual
                .frame(width: 360, height: 360)

            // 展品名
            Text(exhibit.objectName)
                .font(.system(size: 110, weight: .ultraLight, design: .serif))
                .tracking(24)
                .multilineTextAlignment(.center)

            // 书名 + 作者
            VStack(spacing: 12) {
                Text("《\(exhibit.book.title)》")
                    .font(.system(size: 32, weight: .light, design: .serif))
                    .tracking(2)
                    .multilineTextAlignment(.center)
                if let author = exhibit.book.author {
                    Text(author)
                        .font(.system(size: 22, weight: .light, design: .serif))
                        .foregroundStyle(.secondary)
                        .tracking(3)
                }
            }

            DashedLine()
                .padding(.top, 24)

            // 引文/摘要（noteText 第一段）
            Text(firstParagraph)
                .font(.system(size: 26, weight: .light, design: .serif))
                .lineSpacing(12)
                .multilineTextAlignment(.center)
                .foregroundStyle(.primary.opacity(0.88))
                .padding(.horizontal, 20)

            // 时间
            Text(ExhibitTimeFormatter.string(start: exhibit.startedAt, end: exhibit.generatedAt))
                .font(.system(size: 20, weight: .light, design: .serif))
                .foregroundStyle(.tertiary)
                .tracking(3)
                .padding(.top, 8)
        }
    }

    @ViewBuilder
    private var exhibitVisual: some View {
        if let url = exhibit.imageLocalURL,
           let img = UIImage(contentsOfFile: url.path) {
            Image(uiImage: img)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else if let symbol = exhibit.fallbackSymbol {
            Image(systemName: symbol)
                .font(.system(size: 260, weight: .ultraLight))
                .foregroundStyle(.primary.opacity(0.7))
        }
    }

    private var ticketStub: some View {
        VStack(spacing: 32) {
            DashedLine(dashLength: 6, gapLength: 8)

            HStack(alignment: .center) {
                // 左：QR 占位
                if let qrImg = QRCodeGenerator.image(from: shareURL, size: 160) {
                    Image(uiImage: qrImg)
                        .resizable()
                        .interpolation(.none)
                        .frame(width: 140, height: 140)
                        .opacity(0.85)
                } else {
                    Rectangle()
                        .stroke(Color.primary.opacity(0.3), lineWidth: 0.5)
                        .frame(width: 140, height: 140)
                }

                Spacer()

                // 右：签名 + 编号
                VStack(alignment: .trailing, spacing: 10) {
                    Text("MEISHUGUAN")
                        .font(.system(size: 22, weight: .light, design: .serif))
                        .tracking(8)
                    Text("# \(exhibitNumber)")
                        .font(.system(size: 14, weight: .light, design: .serif))
                        .tracking(5)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.top, 24)
    }

    private var firstParagraph: String {
        let normalized = exhibit.noteText.replacingOccurrences(of: "\r\n", with: "\n")
        let paragraphs = normalized
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return paragraphs.first ?? exhibit.noteText
    }

    private var shareURL: String {
        // v1 占位：未来真做 deep link 换 URL
        "meishuguan://exhibit/\(exhibit.id.uuidString)"
    }

    private var exhibitNumber: String {
        String(exhibit.id.uuidString.prefix(6).uppercased())
    }
}

// MARK: - 展厅卡（一本书 + 多件展品）

struct GalleryShareCard: View {
    let gallery: SessionState.Gallery

    var body: some View {
        VStack(spacing: 0) {
            header
            mainContent
            Spacer(minLength: 0)
            ticketStub
        }
        .padding(.horizontal, 100)
        .padding(.vertical, 90)
        .frame(width: 1080, height: 1920)
        .background(Color(.systemBackground))
    }

    private var header: some View {
        VStack(spacing: 10) {
            Text("美 书 馆 · 展 厅")
                .font(.system(size: 32, weight: .light, design: .serif))
                .tracking(8)
            Text("MEISHUGUAN · GALLERY")
                .font(.system(size: 12, weight: .ultraLight, design: .serif))
                .tracking(4)
                .foregroundStyle(.tertiary)
        }
    }

    private var mainContent: some View {
        VStack(spacing: 64) {
            DashedLine()
                .padding(.top, 80)

            // 书名 + 作者
            VStack(spacing: 16) {
                Text("《\(gallery.book.title)》")
                    .font(.system(size: 56, weight: .light, design: .serif))
                    .tracking(4)
                    .multilineTextAlignment(.center)
                if let author = gallery.book.author {
                    Text(author)
                        .font(.system(size: 26, weight: .light, design: .serif))
                        .foregroundStyle(.secondary)
                        .tracking(3)
                }
            }
            .padding(.top, 32)

            // 件数 + 时间
            VStack(spacing: 12) {
                Text("\(gallery.exhibits.count) 件 展 品")
                    .font(.system(size: 28, weight: .light, design: .serif))
                    .tracking(6)
                Text(galleryTimeSpan)
                    .font(.system(size: 18, weight: .light, design: .serif))
                    .foregroundStyle(.tertiary)
                    .tracking(2)
            }

            DashedLine()
                .padding(.top, 40)

            // 所有展品名横排
            objectNamesGrid
                .padding(.top, 16)
        }
    }

    private var objectNamesGrid: some View {
        let names = gallery.exhibits.map(\.objectName)
        return VStack(spacing: 32) {
            if names.count <= 3 {
                HStack(spacing: 60) {
                    ForEach(Array(names.enumerated()), id: \.offset) { _, name in
                        Text(name)
                            .font(.system(size: 56, weight: .ultraLight, design: .serif))
                            .tracking(8)
                    }
                }
            } else {
                // 多于 3 件，换行排版
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 40), count: 3), spacing: 36) {
                    ForEach(Array(names.enumerated()), id: \.offset) { _, name in
                        Text(name)
                            .font(.system(size: 44, weight: .ultraLight, design: .serif))
                            .tracking(6)
                            .lineLimit(1)
                    }
                }
            }
        }
    }

    private var ticketStub: some View {
        VStack(spacing: 32) {
            DashedLine(dashLength: 6, gapLength: 8)

            HStack(alignment: .center) {
                if let qrImg = QRCodeGenerator.image(from: shareURL, size: 160) {
                    Image(uiImage: qrImg)
                        .resizable()
                        .interpolation(.none)
                        .frame(width: 140, height: 140)
                        .opacity(0.85)
                } else {
                    Rectangle()
                        .stroke(Color.primary.opacity(0.3), lineWidth: 0.5)
                        .frame(width: 140, height: 140)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 10) {
                    Text("MEISHUGUAN")
                        .font(.system(size: 22, weight: .light, design: .serif))
                        .tracking(8)
                    Text("# \(galleryNumber)")
                        .font(.system(size: 14, weight: .light, design: .serif))
                        .tracking(5)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.top, 24)
    }

    private var galleryTimeSpan: String {
        let exhibits = gallery.exhibits
        guard let first = exhibits.first, let last = exhibits.last else { return "" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年M月"
        let s = formatter.string(from: first.generatedAt)
        let e = formatter.string(from: last.generatedAt)
        return s == e ? s : "\(s) — \(e)"
    }

    private var shareURL: String {
        "meishuguan://gallery/\(gallery.titleKey)"
    }

    private var galleryNumber: String {
        String(gallery.titleKey.prefix(6).uppercased())
    }
}

// MARK: - 展馆卡（整个 app）

struct MuseumShareCard: View {
    let galleries: [SessionState.Gallery]

    var body: some View {
        VStack(spacing: 0) {
            header
            mainContent
            Spacer(minLength: 0)
            ticketStub
        }
        .padding(.horizontal, 100)
        .padding(.vertical, 90)
        .frame(width: 1080, height: 1920)
        .background(Color(.systemBackground))
    }

    private var header: some View {
        VStack(spacing: 10) {
            Text("美 书 馆")
                .font(.system(size: 38, weight: .light, design: .serif))
                .tracking(12)
            Text("MEISHUGUAN")
                .font(.system(size: 13, weight: .ultraLight, design: .serif))
                .tracking(6)
                .foregroundStyle(.tertiary)
        }
    }

    private var mainContent: some View {
        VStack(spacing: 64) {
            DashedLine()
                .padding(.top, 120)

            Text("我 的 美 书 馆")
                .font(.system(size: 56, weight: .ultraLight, design: .serif))
                .tracking(12)
                .padding(.top, 60)

            VStack(spacing: 20) {
                Text("\(totalExhibits) 件 展 品")
                    .font(.system(size: 32, weight: .light, design: .serif))
                    .tracking(6)
                Text("\(galleries.count) 个 展 厅")
                    .font(.system(size: 24, weight: .light, design: .serif))
                    .tracking(5)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 16)

            DashedLine()
                .padding(.top, 40)

            // 最近读过
            VStack(spacing: 22) {
                Text("最 近 读 过")
                    .font(.system(size: 18, weight: .light, design: .serif))
                    .tracking(6)
                    .foregroundStyle(.tertiary)
                    .padding(.bottom, 8)
                ForEach(recentTitles, id: \.self) { title in
                    Text("《\(title)》")
                        .font(.system(size: 28, weight: .light, design: .serif))
                        .tracking(2)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.top, 16)
        }
    }

    private var ticketStub: some View {
        VStack(spacing: 32) {
            DashedLine(dashLength: 6, gapLength: 8)

            HStack(alignment: .center) {
                if let qrImg = QRCodeGenerator.image(from: shareURL, size: 160) {
                    Image(uiImage: qrImg)
                        .resizable()
                        .interpolation(.none)
                        .frame(width: 140, height: 140)
                        .opacity(0.85)
                } else {
                    Rectangle()
                        .stroke(Color.primary.opacity(0.3), lineWidth: 0.5)
                        .frame(width: 140, height: 140)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 10) {
                    Text("MEISHUGUAN")
                        .font(.system(size: 22, weight: .light, design: .serif))
                        .tracking(8)
                    Text("无 限 期 通 票")
                        .font(.system(size: 14, weight: .light, design: .serif))
                        .tracking(5)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.top, 24)
    }

    private var totalExhibits: Int {
        galleries.reduce(0) { $0 + $1.exhibits.count }
    }

    private var recentTitles: [String] {
        galleries.prefix(3).map { $0.book.title }
    }

    private var shareURL: String {
        "meishuguan://museum"
    }
}
