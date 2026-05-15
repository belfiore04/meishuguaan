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
    let intro: String      // LLM 生成的展厅引言

    var body: some View {
        VStack(spacing: 0) {
            header
            Spacer(minLength: 60)
            bookSection
            Spacer(minLength: 60)
            DashedLine()
            Spacer(minLength: 50)
            introSection
            Spacer(minLength: 50)
            DashedLine()
            Spacer(minLength: 50)
            exhibitsRow
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
                .font(.system(size: 30, weight: .light, design: .serif))
                .tracking(8)
            Text("MEISHUGUAN · GALLERY")
                .font(.system(size: 12, weight: .ultraLight, design: .serif))
                .tracking(4)
                .foregroundStyle(.tertiary)
        }
    }

    private var bookSection: some View {
        VStack(spacing: 18) {
            Text("《\(gallery.book.title)》")
                .font(.system(size: 52, weight: .light, design: .serif))
                .tracking(4)
                .multilineTextAlignment(.center)
            if let author = gallery.book.author {
                Text(author)
                    .font(.system(size: 24, weight: .light, design: .serif))
                    .foregroundStyle(.secondary)
                    .tracking(3)
            }
            HStack(spacing: 20) {
                Text("\(gallery.exhibits.count) 件 展 品")
                    .font(.system(size: 18, weight: .light, design: .serif))
                    .tracking(5)
                    .foregroundStyle(.tertiary)
                Text("·")
                    .font(.system(size: 18, weight: .light, design: .serif))
                    .foregroundStyle(.tertiary)
                Text(galleryTimeSpan)
                    .font(.system(size: 18, weight: .light, design: .serif))
                    .foregroundStyle(.tertiary)
                    .tracking(2)
            }
            .padding(.top, 8)
        }
    }

    private var introSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            ForEach(paragraphs(of: intro), id: \.self) { para in
                Text(para)
                    .font(.system(size: 26, weight: .light, design: .serif))
                    .lineSpacing(12)
                    .multilineTextAlignment(.leading)
                    .foregroundStyle(.primary.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var exhibitsRow: some View {
        let exhibits = gallery.exhibits
        switch exhibits.count {
        case 1:
            HStack {
                Spacer()
                GalleryExhibitTile(exhibit: exhibits[0], visualSize: 180, nameSize: 28, nameTracking: 6)
                Spacer()
            }
        case 2:
            HStack(spacing: 100) {
                ForEach(exhibits) { ex in
                    GalleryExhibitTile(exhibit: ex, visualSize: 150, nameSize: 24, nameTracking: 5)
                }
            }
        case 3:
            HStack(spacing: 60) {
                ForEach(exhibits) { ex in
                    GalleryExhibitTile(exhibit: ex, visualSize: 130, nameSize: 22, nameTracking: 4)
                }
            }
        default:
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 30), count: 4), spacing: 30) {
                ForEach(exhibits.prefix(8)) { ex in
                    GalleryExhibitTile(exhibit: ex, visualSize: 110, nameSize: 18, nameTracking: 2)
                }
            }
        }
    }

    private var ticketStub: some View {
        VStack(spacing: 28) {
            DashedLine(dashLength: 6, gapLength: 8)
            HStack(alignment: .center) {
                if let qrImg = QRCodeGenerator.image(from: shareURL, size: 160) {
                    Image(uiImage: qrImg)
                        .resizable()
                        .interpolation(.none)
                        .frame(width: 130, height: 130)
                        .opacity(0.85)
                } else {
                    Rectangle()
                        .stroke(Color.primary.opacity(0.3), lineWidth: 0.5)
                        .frame(width: 130, height: 130)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 8) {
                    Text("MEISHUGUAN")
                        .font(.system(size: 20, weight: .light, design: .serif))
                        .tracking(8)
                    Text("# \(galleryNumber)")
                        .font(.system(size: 13, weight: .light, design: .serif))
                        .tracking(5)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.top, 20)
    }

    private func paragraphs(of text: String) -> [String] {
        var t = text.replacingOccurrences(of: "\r\n", with: "\n")
        while t.contains("\n\n\n") {
            t = t.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        }
        let byDouble = t.components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if byDouble.count > 1 { return byDouble }
        return t.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
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

// MARK: - 展厅卡里单个展品的视觉 + 名字

private struct GalleryExhibitTile: View {
    let exhibit: Exhibit
    let visualSize: CGFloat
    let nameSize: CGFloat
    let nameTracking: CGFloat

    var body: some View {
        VStack(spacing: 16) {
            // 视觉
            ZStack {
                if let url = exhibit.imageLocalURL,
                   let img = UIImage(contentsOfFile: url.path) {
                    Image(uiImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else if let symbol = exhibit.fallbackSymbol {
                    Image(systemName: symbol)
                        .font(.system(size: visualSize * 0.55, weight: .ultraLight))
                        .foregroundStyle(.primary.opacity(0.7))
                }
            }
            .frame(width: visualSize, height: visualSize)

            Text(exhibit.objectName)
                .font(.system(size: nameSize, weight: .ultraLight, design: .serif))
                .tracking(nameTracking)
                .lineLimit(1)
        }
    }
}

// MARK: - 展馆卡（整个 app）

struct MuseumShareCard: View {
    let galleries: [SessionState.Gallery]
    let intro: String       // LLM 生成的开门致辞

    var body: some View {
        VStack(spacing: 0) {
            header
            Spacer(minLength: 100)
            titleSection
            Spacer(minLength: 60)
            DashedLine()
            Spacer(minLength: 50)
            introSection
            Spacer(minLength: 50)
            DashedLine()
            Spacer(minLength: 50)
            statsAndRecent
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

    private var titleSection: some View {
        Text("我 的 美 书 馆")
            .font(.system(size: 54, weight: .ultraLight, design: .serif))
            .tracking(12)
    }

    private var introSection: some View {
        VStack(alignment: .leading, spacing: 22) {
            ForEach(paragraphs(of: intro), id: \.self) { para in
                Text(para)
                    .font(.system(size: 24, weight: .light, design: .serif))
                    .lineSpacing(11)
                    .multilineTextAlignment(.leading)
                    .foregroundStyle(.primary.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var statsAndRecent: some View {
        VStack(spacing: 36) {
            HStack(spacing: 60) {
                statItem(value: "\(totalExhibits)", label: "件 展 品")
                Rectangle().fill(Color.primary.opacity(0.2)).frame(width: 0.5, height: 40)
                statItem(value: "\(galleries.count)", label: "个 展 厅")
            }

            VStack(spacing: 18) {
                Text("最 近 读 过")
                    .font(.system(size: 15, weight: .light, design: .serif))
                    .tracking(6)
                    .foregroundStyle(.tertiary)
                    .padding(.bottom, 4)
                ForEach(recentTitles, id: \.self) { title in
                    Text("《\(title)》")
                        .font(.system(size: 24, weight: .light, design: .serif))
                        .tracking(2)
                        .multilineTextAlignment(.center)
                }
            }
        }
    }

    private func statItem(value: String, label: String) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(size: 44, weight: .ultraLight, design: .serif))
            Text(label)
                .font(.system(size: 13, weight: .light, design: .serif))
                .tracking(4)
                .foregroundStyle(.tertiary)
        }
    }

    private var ticketStub: some View {
        VStack(spacing: 28) {
            DashedLine(dashLength: 6, gapLength: 8)
            HStack(alignment: .center) {
                if let qrImg = QRCodeGenerator.image(from: shareURL, size: 160) {
                    Image(uiImage: qrImg)
                        .resizable()
                        .interpolation(.none)
                        .frame(width: 130, height: 130)
                        .opacity(0.85)
                } else {
                    Rectangle()
                        .stroke(Color.primary.opacity(0.3), lineWidth: 0.5)
                        .frame(width: 130, height: 130)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 8) {
                    Text("MEISHUGUAN")
                        .font(.system(size: 20, weight: .light, design: .serif))
                        .tracking(8)
                    Text("无 限 期 通 票")
                        .font(.system(size: 13, weight: .light, design: .serif))
                        .tracking(5)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.top, 20)
    }

    private func paragraphs(of text: String) -> [String] {
        var t = text.replacingOccurrences(of: "\r\n", with: "\n")
        while t.contains("\n\n\n") {
            t = t.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        }
        let byDouble = t.components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if byDouble.count > 1 { return byDouble }
        return t.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
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
