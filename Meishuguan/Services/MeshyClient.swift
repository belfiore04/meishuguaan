import Foundation

actor MeshyClient {
    static let shared = MeshyClient()

    private let base = URL(string: "https://api.meshy.ai/openapi/v2/text-to-3d")!

    /// 提交 → 轮询 → 下载 .usdz / .glb。返回本地文件 URL。
    /// progress 回调用于驱动等待动画（0...1）。
    /// 注意：Meshy 的 API 在演化中，调用前请校对官方文档。
    func generateObject(
        prompt: String,
        progress: @Sendable @escaping (Double, String) -> Void
    ) async throws -> URL {
        guard !Config.meshyKey.isEmpty else { throw MeshyError.missingKey }

        progress(0.05, "正在提交制作请求…")

        let previewID = try await submitPreview(prompt: prompt)
        progress(0.1, "AI 开始为你做这件物件")

        // 轮询 preview 阶段
        var done = false
        var attempt = 0
        var lastProgressFrac: Double = 0
        while !done {
            try await Task.sleep(nanoseconds: 5_000_000_000) // 5s
            attempt += 1
            let status = try await fetchStatus(taskID: previewID)
            switch status.kind {
            case .pending, .inProgress:
                let frac = max(lastProgressFrac, min(0.7, 0.1 + Double(status.progress) / 200.0))
                lastProgressFrac = frac
                progress(frac, "塑形中… \(status.progress)%")
            case .succeeded:
                done = true
            case .failed(let msg):
                throw MeshyError.generationFailed(msg)
            case .canceled:
                throw MeshyError.generationFailed("任务取消")
            }
            if attempt > 240 { // 20 min cap
                throw MeshyError.generationFailed("生成超时")
            }
        }

        progress(0.8, "正在精修材质…")
        let detail = try await fetchStatus(taskID: previewID)

        // 选择一个可下载的模型 URL，优先 usdz，其次 glb
        guard let modelURL = detail.modelURL else {
            throw MeshyError.generationFailed("没有返回模型文件")
        }

        progress(0.9, "下载到本地…")
        let local = try await downloadModel(remote: modelURL, taskID: previewID)
        progress(1.0, "展品准备好了")
        return local
    }

    // MARK: - Steps

    private func submitPreview(prompt: String) async throws -> String {
        var req = URLRequest(url: base)
        req.httpMethod = "POST"
        req.setValue("Bearer \(Config.meshyKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: [
            "mode": "preview",
            "prompt": prompt,
            "art_style": "sculpture",
            "negative_prompt": "low quality, multiple objects, text, human, character, complex scene"
        ])
        req.timeoutInterval = 30

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw MeshyError.httpError(String(data: data, encoding: .utf8) ?? "")
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let id = (json["result"] as? String) ?? (json["id"] as? String)
        else {
            throw MeshyError.httpError("无法解析提交返回")
        }
        return id
    }

    private struct TaskStatus {
        enum Kind {
            case pending, inProgress, succeeded
            case failed(String)
            case canceled
        }
        var kind: Kind
        var progress: Int
        var modelURL: URL?
    }

    private func fetchStatus(taskID: String) async throws -> TaskStatus {
        var req = URLRequest(url: base.appendingPathComponent(taskID))
        req.setValue("Bearer \(Config.meshyKey)", forHTTPHeaderField: "Authorization")
        req.timeoutInterval = 30

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw MeshyError.httpError(String(data: data, encoding: .utf8) ?? "")
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw MeshyError.httpError("无法解析状态返回")
        }

        let statusStr = (json["status"] as? String)?.uppercased() ?? "PENDING"
        let progress = (json["progress"] as? Int) ?? 0

        let urls = json["model_urls"] as? [String: String]
        let pickedString = urls?["usdz"] ?? urls?["glb"] ?? urls?["fbx"]
        let picked = pickedString.flatMap { URL(string: $0) }

        let kind: TaskStatus.Kind
        switch statusStr {
        case "PENDING": kind = .pending
        case "IN_PROGRESS": kind = .inProgress
        case "SUCCEEDED": kind = .succeeded
        case "FAILED":
            let msg = (json["task_error"] as? [String: Any])?["message"] as? String ?? "失败"
            kind = .failed(msg)
        case "CANCELED": kind = .canceled
        default: kind = .pending
        }
        return TaskStatus(kind: kind, progress: progress, modelURL: picked)
    }

    private func downloadModel(remote: URL, taskID: String) async throws -> URL {
        let (tmp, _) = try await URLSession.shared.download(from: remote)
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Exhibits", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let ext = remote.pathExtension.isEmpty ? "usdz" : remote.pathExtension
        let final = dir.appendingPathComponent("\(taskID).\(ext)")
        try? FileManager.default.removeItem(at: final)
        try FileManager.default.moveItem(at: tmp, to: final)
        return final
    }
}

enum MeshyError: LocalizedError {
    case missingKey
    case httpError(String)
    case generationFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingKey: return "缺少 MESHY_API_KEY，到 Resources/Secrets.plist 填一下。"
        case .httpError(let s): return "Meshy API 出错：\(s.prefix(300))"
        case .generationFailed(let s): return "生成失败：\(s)"
        }
    }
}
