import Foundation
import UIKit

actor ClaudeClient {
    static let shared = ClaudeClient()

    private let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!

    /// 调用 Claude Vision 识别书封 + 给一段简短背景。
    /// 返回 (title, author, brief)。
    func identifyBook(from image: UIImage) async throws -> (title: String, author: String?, brief: String) {
        guard let jpeg = image.jpegData(compressionQuality: 0.7) else {
            throw ClaudeError.imageEncoding
        }
        let base64 = jpeg.base64EncodedString()

        let system = """
        你帮用户识别一本书。看封面照片，输出严格的 JSON：
        {"title": "书名", "author": "作者（可空）", "brief": "两三句话的背景介绍，给真正会读这本书的人看，不要客套"}
        不要 markdown 包裹，不要任何解释。
        """

        let body: [String: Any] = [
            "model": Config.claudeModel,
            "max_tokens": 600,
            "system": system,
            "messages": [
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "image",
                            "source": [
                                "type": "base64",
                                "media_type": "image/jpeg",
                                "data": base64
                            ]
                        ],
                        ["type": "text", "text": "识别这本书。"]
                    ]
                ]
            ]
        ]

        let raw = try await sendNonStreaming(body: body)
        let cleaned = stripCodeFence(raw)
        guard let data = cleaned.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let title = dict["title"] as? String, !title.isEmpty
        else {
            throw ClaudeError.malformedJSON(raw)
        }
        let author = dict["author"] as? String
        let brief = (dict["brief"] as? String) ?? ""
        return (title, author?.isEmpty == true ? nil : author, brief)
    }

    /// 与 AI 书友持续对话。返回这一轮 AI 的回复。
    func reply(book: Book, history: [ChatMessage], userText: String) async throws -> String {
        let system = """
        你是一位安静、有审美修养的书友，正陪用户读《\(book.title)》\(book.author.map { "（作者 \($0)）" } ?? "")。
        \(book.brief.isEmpty ? "" : "你掌握的关于这本书的背景：\(book.brief)")

        语气准则：
        - 被动为主，但会接住用户的话、偶尔反问。
        - 喜欢补一小块上下文（"那一年很奇怪/他刚从某地搬到某地"这种），不科普、不教学、不长篇大论。
        - 用户问什么都答，但答得短而准。
        - 不要使用 emoji、不要使用 markdown 标题、不要使用列表符号。
        - 中文为主。
        - 单次回复一般控制在 2-4 句话之内。
        """

        var apiMessages: [[String: Any]] = []
        for m in history {
            apiMessages.append([
                "role": m.role == .user ? "user" : "assistant",
                "content": m.text
            ])
        }
        apiMessages.append(["role": "user", "content": userText])

        let body: [String: Any] = [
            "model": Config.claudeModel,
            "max_tokens": 600,
            "system": system,
            "messages": apiMessages
        ]
        return try await sendNonStreaming(body: body)
    }

    /// 会话结束 → 让 Claude 输出三件事：笔记文本、3D 物件 prompt、物件简短中文名。
    func summarize(book: Book, messages: [ChatMessage]) async throws -> (note: String, objectPrompt: String, objectName: String) {
        let convo = messages.map { ($0.role == .user ? "我" : "书友") + "：" + $0.text }.joined(separator: "\n")

        let system = """
        你是一位策展人，正在把一段读书对话变成一件博物馆展品。
        输出严格的 JSON（不要 markdown 包裹）：
        {
          "note": "整理这次对话产生的读书笔记，500 字以内，以用户原话为主、AI 补充为辅，分自然段，不要小标题",
          "objectName": "用一个中文短词命名这件展品（例如：尺、云、镐、灯、水），最多 4 个汉字",
          "objectPrompt": "一段英文 prompt，喂给图像生成模型生成这件展品的 3D 渲染图。强调：a single small object centered on a soft white background, museum-quality 3D render, soft studio lighting, low-poly stylized, monochrome with one subtle accent color extracted from the book's mood. 严格禁止：no text, no people, no complex scene, no multiple objects."
        }
        """

        let body: [String: Any] = [
            "model": Config.claudeModel,
            "max_tokens": 1500,
            "system": system,
            "messages": [
                [
                    "role": "user",
                    "content": "书：《\(book.title)》\(book.author.map { "（作者 \($0)）" } ?? "")\n\n对话：\n\(convo)"
                ]
            ]
        ]

        let raw = try await sendNonStreaming(body: body)
        let cleaned = stripCodeFence(raw)
        guard let data = cleaned.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let note = dict["note"] as? String,
              let prompt = dict["objectPrompt"] as? String,
              let name = dict["objectName"] as? String
        else {
            throw ClaudeError.malformedJSON(raw)
        }
        return (note, prompt, name)
    }

    // MARK: - Networking

    private func sendNonStreaming(body: [String: Any]) async throws -> String {
        guard !Config.anthropicKey.isEmpty else { throw ClaudeError.missingKey }

        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue(Config.anthropicKey, forHTTPHeaderField: "x-api-key")
        req.setValue(Config.anthropicVersion, forHTTPHeaderField: "anthropic-version")
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        req.timeoutInterval = 60

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let s = String(data: data, encoding: .utf8) ?? ""
            throw ClaudeError.httpError(s)
        }

        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let content = json["content"] as? [[String: Any]],
            let first = content.first,
            let text = first["text"] as? String
        else {
            throw ClaudeError.malformedJSON(String(data: data, encoding: .utf8) ?? "")
        }
        return text
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

enum ClaudeError: LocalizedError {
    case missingKey
    case imageEncoding
    case httpError(String)
    case malformedJSON(String)

    var errorDescription: String? {
        switch self {
        case .missingKey: return "缺少 ANTHROPIC_API_KEY，到 Resources/Secrets.plist 填一下。"
        case .imageEncoding: return "图片编码失败。"
        case .httpError(let s): return "Claude API 出错：\(s.prefix(300))"
        case .malformedJSON(let s): return "无法解析 Claude 返回：\(s.prefix(300))"
        }
    }
}
