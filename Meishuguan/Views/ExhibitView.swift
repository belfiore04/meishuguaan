import SwiftUI
import SceneKit

struct ExhibitView: View {
    @Environment(SessionState.self) private var session
    let exhibit: Exhibit

    @State private var showNote: Bool = false

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                ExhibitStage(exhibit: exhibit)
                bottomBar
            }
        }
        .sheet(isPresented: $showNote) {
            ExhibitLabelView(exhibit: exhibit) { newName in
                session.renameExhibit(id: exhibit.id, to: newName)
            }
            .presentationDetents([.medium, .large])
            .presentationBackground(.regularMaterial)
        }
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
            Text(exhibit.book.title)
                .font(.system(.subheadline, design: .serif))
            Spacer()
            Color.clear.frame(width: 32, height: 32)
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }

    private var bottomBar: some View {
        VStack(spacing: 8) {
            Text(exhibit.objectName)
                .font(.system(size: 22, weight: .light, design: .serif))
                .tracking(4)
                .padding(.bottom, 2)

            Text(ExhibitTimeFormatter.string(start: exhibit.startedAt, end: exhibit.generatedAt))
                .font(.system(size: 10, design: .serif))
                .foregroundStyle(.tertiary)
                .tracking(1)

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

            Text("再读一本书")
                .font(.system(.footnote, design: .serif))
                .foregroundStyle(.tertiary)
                .onTapGesture {
                    session.returnToLobby()
                }
                .padding(.top, 8)
                .padding(.bottom, 24)
        }
    }
}

// MARK: - 展品视觉舞台

struct ExhibitStage: View {
    let exhibit: Exhibit

    var body: some View {
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
    }
}

// MARK: - SceneKit stage

struct ModelStageView: UIViewRepresentable {
    let modelURL: URL

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.backgroundColor = .systemBackground
        view.allowsCameraControl = true
        view.autoenablesDefaultLighting = false
        view.antialiasingMode = .multisampling4X
        view.scene = makeScene()
        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {}

    private func makeScene() -> SCNScene {
        let scene = SCNScene()

        // 白色展台
        let pedestal = SCNBox(width: 1.4, height: 0.2, length: 1.4, chamferRadius: 0.01)
        pedestal.firstMaterial?.diffuse.contents = UIColor.systemGray6
        pedestal.firstMaterial?.lightingModel = .physicallyBased
        let pedestalNode = SCNNode(geometry: pedestal)
        pedestalNode.position = SCNVector3(0, -0.3, 0)
        scene.rootNode.addChildNode(pedestalNode)

        // 加载用户的 3D 物件
        if let modelScene = try? SCNScene(url: modelURL) {
            let modelNode = SCNNode()
            for child in modelScene.rootNode.childNodes {
                modelNode.addChildNode(child)
            }
            let (minB, maxB) = modelNode.boundingBox
            let extent = max(maxB.x - minB.x, max(maxB.y - minB.y, maxB.z - minB.z))
            if extent > 0 {
                let scale = 0.8 / extent
                modelNode.scale = SCNVector3(scale, scale, scale)
            }
            let mid = SCNVector3(
                (minB.x + maxB.x) / 2,
                (minB.y + maxB.y) / 2,
                (minB.z + maxB.z) / 2
            )
            modelNode.pivot = SCNMatrix4MakeTranslation(mid.x, mid.y, mid.z)
            modelNode.position = SCNVector3(0, 0.1, 0)
            scene.rootNode.addChildNode(modelNode)

            let rotate = SCNAction.rotate(by: .pi * 2, around: SCNVector3(0, 1, 0), duration: 24)
            modelNode.runAction(SCNAction.repeatForever(rotate))
        }

        let key = SCNNode()
        key.light = SCNLight()
        key.light?.type = .directional
        key.light?.intensity = 800
        key.light?.color = UIColor.white
        key.eulerAngles = SCNVector3(-Float.pi / 4, Float.pi / 4, 0)
        scene.rootNode.addChildNode(key)

        let fill = SCNNode()
        fill.light = SCNLight()
        fill.light?.type = .ambient
        fill.light?.intensity = 400
        fill.light?.color = UIColor.white
        scene.rootNode.addChildNode(fill)

        let cam = SCNNode()
        cam.camera = SCNCamera()
        cam.camera?.fieldOfView = 35
        cam.position = SCNVector3(0, 0.5, 2.4)
        cam.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(cam)

        return scene
    }
}

// MARK: - 展台说明卡（一级标题展品名 + 二级标题时间 + 正文 + 看完整对话）

struct ExhibitLabelView: View {
    let exhibit: Exhibit
    var onRename: (String) -> Void = { _ in }

    @State private var editingName: Bool = false
    @State private var nameDraft: String = ""
    @State private var showFullChat: Bool = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // 一级标题：展品名（点击进入编辑态）
                if editingName {
                    TextField("", text: $nameDraft)
                        .font(.system(size: 28, weight: .light, design: .serif))
                        .tracking(4)
                        .submitLabel(.done)
                        .onSubmit { commitNameEdit() }
                } else {
                    Text(exhibit.objectName)
                        .font(.system(size: 28, weight: .light, design: .serif))
                        .tracking(4)
                        .onTapGesture {
                            nameDraft = exhibit.objectName
                            editingName = true
                        }
                }

                // 二级标题：创作时间
                Text(ExhibitTimeFormatter.longString(start: exhibit.startedAt, end: exhibit.generatedAt))
                    .font(.system(size: 11, design: .serif))
                    .foregroundStyle(.tertiary)
                    .tracking(1)
                    .padding(.top, 6)

                Divider().padding(.vertical, 20)

                // 正文
                Text(exhibit.noteText)
                    .font(.system(.body, design: .serif))
                    .lineSpacing(7)
                    .multilineTextAlignment(.leading)
                    .foregroundStyle(.primary.opacity(0.92))

                // 看完整对话
                if !exhibit.messages.isEmpty {
                    Divider().padding(.top, 28).padding(.bottom, 16)

                    if showFullChat {
                        Text("完整对话")
                            .font(.system(size: 11, design: .serif))
                            .foregroundStyle(.tertiary)
                            .tracking(1)
                            .padding(.bottom, 12)

                        VStack(alignment: .leading, spacing: 16) {
                            ForEach(exhibit.messages) { msg in
                                HStack(alignment: .top, spacing: 8) {
                                    Text(msg.role == .user ? "我" : "书友")
                                        .font(.system(size: 11, design: .serif))
                                        .foregroundStyle(.tertiary)
                                        .frame(width: 30, alignment: .leading)
                                    Text(msg.text)
                                        .font(.system(.footnote, design: .serif))
                                        .foregroundStyle(.primary.opacity(0.85))
                                        .multilineTextAlignment(.leading)
                                }
                            }
                        }
                        .padding(.bottom, 24)
                    } else {
                        Button {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showFullChat = true
                            }
                        } label: {
                            Text("看完整对话 →")
                                .font(.system(.footnote, design: .serif))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding(.horizontal, 28)
            .padding(.top, 36)
            .padding(.bottom, 40)
        }
    }

    private func commitNameEdit() {
        editingName = false
        let trimmed = nameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != exhibit.objectName else { return }
        onRename(trimmed)
    }
}

// MARK: - 时间格式化

enum ExhibitTimeFormatter {
    /// 短：「2026年5月15日 22:14–22:38」
    static func string(start: Date?, end: Date?) -> String {
        guard let end else { return "" }
        let cal = Calendar.current
        let dateFmt = DateFormatter()
        dateFmt.locale = Locale(identifier: "zh_CN")
        dateFmt.dateFormat = "yyyy年M月d日"
        let date = dateFmt.string(from: end)
        let timeFmt = DateFormatter()
        timeFmt.locale = Locale(identifier: "zh_CN")
        timeFmt.dateFormat = "HH:mm"
        if let start, cal.isDate(start, inSameDayAs: end) {
            return "\(date) \(timeFmt.string(from: start))–\(timeFmt.string(from: end))"
        }
        return "\(date) \(timeFmt.string(from: end))"
    }

    /// 长：和 string() 一样，给说明卡用，留着以后可以扩
    static func longString(start: Date?, end: Date?) -> String {
        string(start: start, end: end)
    }
}
