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
                exhibitArea
                bottomBar
            }
        }
        .sheet(isPresented: $showNote) {
            NotePaperView(noteText: exhibit.noteText, book: exhibit.book)
                .presentationDetents([.medium, .large])
                .presentationBackground(.regularMaterial)
        }
    }

    private var topBar: some View {
        HStack {
            Button {
                session.reset()
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

    private var exhibitArea: some View {
        ZStack {
            if let url = exhibit.imageLocalURL,
               let img = UIImage(contentsOfFile: url.path) {
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(40)
            } else if let url = exhibit.modelLocalURL {
                ModelStageView(modelURL: url)
            } else {
                Text("展品文件丢失")
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxHeight: .infinity)
    }

    private var bottomBar: some View {
        VStack(spacing: 14) {
            Button {
                showNote = true
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
                .overlay(
                    Capsule().stroke(.tertiary, lineWidth: 0.5)
                )
            }

            Text("再读一本书")
                .font(.system(.footnote, design: .serif))
                .foregroundStyle(.tertiary)
                .onTapGesture {
                    session.reset()
                }
                .padding(.bottom, 24)
        }
    }
}

// MARK: - SceneKit stage

private struct ModelStageView: UIViewRepresentable {
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
            // 估算并归一化大小到约 0.8 个单位
            let (minB, maxB) = modelNode.boundingBox
            let extent = max(maxB.x - minB.x, max(maxB.y - minB.y, maxB.z - minB.z))
            if extent > 0 {
                let scale = 0.8 / extent
                modelNode.scale = SCNVector3(scale, scale, scale)
            }
            // 居中
            let mid = SCNVector3(
                (minB.x + maxB.x) / 2,
                (minB.y + maxB.y) / 2,
                (minB.z + maxB.z) / 2
            )
            modelNode.pivot = SCNMatrix4MakeTranslation(mid.x, mid.y, mid.z)
            modelNode.position = SCNVector3(0, 0.1, 0)
            scene.rootNode.addChildNode(modelNode)

            // 缓慢自转
            let rotate = SCNAction.rotate(by: .pi * 2, around: SCNVector3(0, 1, 0), duration: 24)
            modelNode.runAction(SCNAction.repeatForever(rotate))
        }

        // 灯光
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

        // 相机
        let cam = SCNNode()
        cam.camera = SCNCamera()
        cam.camera?.fieldOfView = 35
        cam.position = SCNVector3(0, 0.5, 2.4)
        cam.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(cam)

        return scene
    }
}

// MARK: - Note paper sheet

private struct NotePaperView: View {
    let noteText: String
    let book: Book

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(book.title)
                        .font(.system(.headline, design: .serif))
                    if let author = book.author {
                        Text(author)
                            .font(.system(.caption, design: .serif))
                            .foregroundStyle(.tertiary)
                    }
                }
                Divider()
                Text(noteText)
                    .font(.system(.body, design: .serif))
                    .lineSpacing(6)
                    .multilineTextAlignment(.leading)
            }
            .padding(28)
        }
    }
}
