import Foundation

/// 生成展品的图像。
///
/// 双路径：
/// - 默认走 **Pollinations**（完全免费、无 key、纯 GET 一张 PNG），适合 prototype 验证。
/// - 如果在 Secrets.plist 填了 `REPLICATE_API_TOKEN`，自动切到 **Replicate flux-schnell**
///   （~$0.003/张，质量好得多、稳得多）。
///
/// 等以后真要 3D 物件再切 [[MeshyClient]] 或 Hugging Face InstantMesh。
actor ImageGenerationClient {
    static let shared = ImageGenerationClient()

    func generateImage(
        prompt: String,
        progress: @Sendable @escaping (Double, String) -> Void
    ) async throws -> URL {
        if !Config.replicateToken.isEmpty {
            return try await generateViaReplicate(prompt: prompt, progress: progress)
        } else {
            return try await generateViaPollinations(prompt: prompt, progress: progress)
        }
    }

    // MARK: - Pollinations (免费)

    private func generateViaPollinations(
        prompt: String,
        progress: @Sendable @escaping (Double, String) -> Void
    ) async throws -> URL {
        progress(0.1, "AI 拿起笔…")

        let encoded = prompt.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? prompt
        let urlStr = "https://image.pollinations.ai/prompt/\(encoded)?width=1024&height=1024&model=flux&nologo=true&enhance=true&seed=\(Int.random(in: 1...999_999))"
        guard let url = URL(string: urlStr) else { throw ImageGenError.urlInvalid }

        // 假装进度爬升，让等待动画不死
        let progressTask = Task { @Sendable in
            var p = 0.15
            while !Task.isCancelled && p < 0.85 {
                progress(p, "塑形中…")
                try? await Task.sleep(nanoseconds: 800_000_000)
                p += 0.04
            }
        }

        var req = URLRequest(url: url)
        req.timeoutInterval = 120
        let (data, response) = try await URLSession.shared.data(for: req)
        progressTask.cancel()

        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ImageGenError.httpError("Pollinations HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)")
        }

        progress(0.92, "保存到展柜…")
        let local = try savePNG(data: data)
        progress(1.0, "展品准备好了")
        return local
    }

    // MARK: - Replicate flux-schnell (~$0.003/张)

    private func generateViaReplicate(
        prompt: String,
        progress: @Sendable @escaping (Double, String) -> Void
    ) async throws -> URL {
        progress(0.05, "提交给 Replicate…")

        // 1. 提交 prediction
        let createURL = URL(string: "https://api.replicate.com/v1/models/black-forest-labs/flux-schnell/predictions")!
        var req = URLRequest(url: createURL)
        req.httpMethod = "POST"
        req.setValue("Bearer \(Config.replicateToken)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("wait", forHTTPHeaderField: "Prefer")  // 同步等待结果（最长 60s）
        req.httpBody = try JSONSerialization.data(withJSONObject: [
            "input": [
                "prompt": prompt,
                "aspect_ratio": "1:1",
                "output_format": "png",
                "num_outputs": 1,
                "num_inference_steps": 4
            ]
        ])
        req.timeoutInterval = 90

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ImageGenError.httpError("Replicate HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0): \(String(data: data, encoding: .utf8)?.prefix(200) ?? "")")
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ImageGenError.httpError("Replicate 返回无法解析")
        }

        progress(0.6, "拿到图…")

        // 同步模式下 output 应该已经在返回里
        let outputs = json["output"] as? [String]
        if let first = outputs?.first, let imgURL = URL(string: first) {
            return try await downloadAndSave(from: imgURL, progress: progress)
        }

        // 万一没等到（>60s），轮询 prediction
        guard let urls = json["urls"] as? [String: String],
              let getURL = urls["get"].flatMap(URL.init(string:))
        else {
            throw ImageGenError.httpError("Replicate 没返回 prediction URL")
        }

        return try await pollReplicate(getURL: getURL, progress: progress)
    }

    private func pollReplicate(
        getURL: URL,
        progress: @Sendable @escaping (Double, String) -> Void
    ) async throws -> URL {
        var attempt = 0
        while true {
            try await Task.sleep(nanoseconds: 2_000_000_000)
            attempt += 1
            if attempt > 120 { throw ImageGenError.httpError("Replicate 轮询超时") }

            var req = URLRequest(url: getURL)
            req.setValue("Bearer \(Config.replicateToken)", forHTTPHeaderField: "Authorization")
            let (data, _) = try await URLSession.shared.data(for: req)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
            let status = (json["status"] as? String) ?? ""
            switch status {
            case "succeeded":
                if let outputs = json["output"] as? [String], let first = outputs.first, let imgURL = URL(string: first) {
                    return try await downloadAndSave(from: imgURL, progress: progress)
                }
                throw ImageGenError.httpError("Replicate succeeded 但无 output")
            case "failed", "canceled":
                throw ImageGenError.httpError("Replicate \(status): \(json["error"] ?? "")")
            default:
                progress(min(0.85, 0.6 + Double(attempt) * 0.02), "Replicate \(status)…")
            }
        }
    }

    // MARK: - Helpers

    private func downloadAndSave(
        from url: URL,
        progress: @Sendable @escaping (Double, String) -> Void
    ) async throws -> URL {
        progress(0.9, "下载图像…")
        let (data, _) = try await URLSession.shared.data(from: url)
        let local = try savePNG(data: data)
        progress(1.0, "展品准备好了")
        return local
    }

    private func savePNG(data: Data) throws -> URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Exhibits", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let local = dir.appendingPathComponent("\(UUID().uuidString).png")
        try data.write(to: local)
        return local
    }
}

enum ImageGenError: LocalizedError {
    case urlInvalid
    case httpError(String)

    var errorDescription: String? {
        switch self {
        case .urlInvalid: return "无法构造图像生成 URL"
        case .httpError(let s): return "图像生成失败：\(s)"
        }
    }
}
