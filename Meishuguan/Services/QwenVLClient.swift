import Foundation
import UIKit

/// 阿里云 DashScope（通义千问 Qwen-VL）— 用于书封 Vision 识别。
/// 走 OpenAI 兼容模式，接口和 OpenAI vision 标准格式一致。
/// 文档：https://help.aliyun.com/zh/model-studio/developer-reference/use-qwen-by-calling-api
actor QwenVLClient {
    static let shared = QwenVLClient()

    private let endpoint = URL(string: "https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions")!

    /// 用 Qwen-VL 识别书封 + 给一段简短背景。
    /// 返回 (title, author, brief)。
    func identifyBook(from image: UIImage) async throws -> (title: String, author: String?, brief: String) {
        guard !Config.dashscopeKey.isEmpty else { throw QwenVLError.missingKey }
        guard let jpeg = image.jpegData(compressionQuality: 0.7) else {
            throw QwenVLError.imageEncoding
        }
        let dataURL = "data:image/jpeg;base64,\(jpeg.base64EncodedString())"

        let system = """
        你帮用户识别一本书。看封面照片，输出严格的 JSON：
        {"title": "书名", "author": "作者（可空）", "brief": "两三句话的背景介绍，给真正会读这本书的人看，不要客套"}
        不要 markdown 包裹，不要任何解释。
        """

        let body: [String: Any] = [
            "model": Config.qwenVisionModel,
            "messages": [
                ["role": "system", "content": system],
                [
                    "role": "user",
                    "content": [
                        ["type": "image_url", "image_url": ["url": dataURL]],
                        ["type": "text", "text": "识别这本书。"]
                    ]
                ]
            ],
            "max_tokens": 600,
            "temperature": 0.3
        ]

        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("Bearer \(Config.dashscopeKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        req.timeoutInterval = 60

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let s = String(data: data, encoding: .utf8) ?? ""
            throw QwenVLError.httpError(s)
        }

        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let choices = json["choices"] as? [[String: Any]],
            let first = choices.first,
            let message = first["message"] as? [String: Any],
            let raw = message["content"] as? String
        else {
            throw QwenVLError.malformedJSON(String(data: data, encoding: .utf8) ?? "")
        }

        let cleaned = stripCodeFence(raw)
        guard let jsonData = cleaned.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let title = dict["title"] as? String, !title.isEmpty
        else {
            throw QwenVLError.malformedJSON(raw)
        }
        let author = dict["author"] as? String
        let brief = (dict["brief"] as? String) ?? ""
        return (title, author?.isEmpty == true ? nil : author, brief)
    }

    private func stripCodeFence(_ s: String) -> String {
        var t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.hasPrefix("```") {
            if let firstNewline = t.firstIndex(of: "\n") {
                t = String(t[t.index(after: firstNewline)...])
            }
            if t.hasSuffix("```") {
                t = String(t.dropLast(3))
            }
        }
        return t.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum QwenVLError: LocalizedError {
    case missingKey
    case imageEncoding
    case httpError(String)
    case malformedJSON(String)

    var errorDescription: String? {
        switch self {
        case .missingKey: return "缺少 DASHSCOPE_API_KEY，到 Resources/Secrets.plist 填一下。"
        case .imageEncoding: return "图片编码失败。"
        case .httpError(let s): return "Qwen-VL API 出错：\(s.prefix(300))"
        case .malformedJSON(let s): return "无法解析 Qwen-VL 返回：\(s.prefix(300))"
        }
    }
}
