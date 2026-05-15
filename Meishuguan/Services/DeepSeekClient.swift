import Foundation

/// DeepSeek 走 OpenAI 兼容 API。便宜得多（~¥几厘一次对话），用于 reply 和 summarize。
/// 书封识别（Vision）走 [[QwenVLClient]]，因为 DeepSeek 官方 API 暂不支持图像输入。
actor DeepSeekClient {
    static let shared = DeepSeekClient()

    private let endpoint = URL(string: "https://api.deepseek.com/chat/completions")!
    private let model = "deepseek-chat"

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

        var apiMessages: [[String: Any]] = [["role": "system", "content": system]]
        for m in history {
            apiMessages.append([
                "role": m.role == .user ? "user" : "assistant",
                "content": m.text
            ])
        }
        apiMessages.append(["role": "user", "content": userText])

        let body: [String: Any] = [
            "model": model,
            "messages": apiMessages,
            "max_tokens": 600,
            "temperature": 0.8,
            "stream": false
        ]

        return try await sendChat(body: body)
    }

    func summarize(book: Book, messages: [ChatMessage]) async throws -> (note: String, objectPrompt: String, objectName: String) {
        let convo = messages.map { ($0.role == .user ? "我" : "书友") + "：" + $0.text }.joined(separator: "\n")

        let system = """
        你是一位策展人。读者刚刚和书友一起读完了《\(book.title)》\(book.author.map { "（作者 \($0)）" } ?? "")。
        你的任务：把这次对话凝成一件展品，并为它写一张博物馆式的展品说明卡。

        绝对不要做：
        - 把对话内容直接复述、罗列、转述、复读。
        - 用「对话中提到」「读者认为」「AI 回应说」这种叙述视角。
        - 写「令人深思」「很有启发」「值得思考」「耐人寻味」「发人深省」这类空话。
        - 教训式总结、给读者下结论、做主题归纳。
        - 使用 emoji、markdown、小标题、列表符号、加粗。
        - 用"读者"这两个字作为人称（直接用"他"或者省略主语）。

        输出严格 JSON（不要 markdown 包裹，不要解释）：
        {
          "objectName": "为这件展品取一个 2-4 字的中文名。
                          这个名字应当从对话里凝出意象——例如反复回到的一个比喻、
                          一个被卡住的概念、一个出现两次的物件、一个未说完的词。
                          示例（仅风格参考）：尺、云、镐、灯、水、骨、门、纸、潮汐、半页、空盏。
                          不要是书名的复述，也不要是抽象大词（如：思考、感悟、记忆、人生）。",

          "note": "一段中文展品说明，约 200-300 字。

                      形式自由：可以是一段，可以两段，可以三段，看对话本身的密度。
                      不要套结构，不要起承转合，不要每段一个分工。
                      让它读起来像一个安静的人在展品旁说了几句话。

                      可以写的方向（不必都写，写得到就写）：
                      - 这次阅读绕着什么转，停在了什么地方。
                      - 哪一句话或哪一个词让对话顿了一下。
                      - 他带走了什么，留下了什么没说完。
                      - 一种感觉、一个疑问、一个未完成的想法。

                      可以引用他一句原话（用「」包），但只引最锋利那一句。
                      第三人称、不口语化、不抒情过度、不教训、不下结论。",

          "objectPrompt": "(英文，给图像模型) a single small object centered on a soft white background, museum-quality 3D render, soft studio lighting, low-poly stylized, monochrome with one subtle accent color extracted from the book's mood. Strict: no text, no people, no complex scene, no multiple objects."
        }
        """

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": "书：《\(book.title)》\(book.author.map { "（作者 \($0)）" } ?? "")\n\n对话：\n\(convo)"]
            ],
            "max_tokens": 1500,
            "temperature": 0.6,
            "response_format": ["type": "json_object"],
            "stream": false
        ]

        let raw = try await sendChat(body: body)
        let cleaned = stripCodeFence(raw)
        guard let data = cleaned.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let note = dict["note"] as? String,
              let prompt = dict["objectPrompt"] as? String,
              let name = dict["objectName"] as? String
        else {
            throw DeepSeekError.malformedJSON(raw)
        }
        return (note, prompt, name)
    }

    // MARK: - Networking

    private func sendChat(body: [String: Any]) async throws -> String {
        guard !Config.deepseekKey.isEmpty else { throw DeepSeekError.missingKey }

        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("Bearer \(Config.deepseekKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        req.timeoutInterval = 60

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let s = String(data: data, encoding: .utf8) ?? ""
            throw DeepSeekError.httpError(s)
        }

        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let choices = json["choices"] as? [[String: Any]],
            let first = choices.first,
            let message = first["message"] as? [String: Any],
            let text = message["content"] as? String
        else {
            throw DeepSeekError.malformedJSON(String(data: data, encoding: .utf8) ?? "")
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

enum DeepSeekError: LocalizedError {
    case missingKey
    case httpError(String)
    case malformedJSON(String)

    var errorDescription: String? {
        switch self {
        case .missingKey: return "缺少 DEEPSEEK_API_KEY，到 Resources/Secrets.plist 填一下。"
        case .httpError(let s): return "DeepSeek API 出错：\(s.prefix(300))"
        case .malformedJSON(let s): return "无法解析 DeepSeek 返回：\(s.prefix(300))"
        }
    }
}
