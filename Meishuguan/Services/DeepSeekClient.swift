import Foundation

/// DeepSeek 走 OpenAI 兼容 API。便宜得多（~¥几厘一次对话），用于 reply 和 summarize。
/// 书封识别（Vision）走 [[QwenVLClient]]，因为 DeepSeek 官方 API 暂不支持图像输入。
actor DeepSeekClient {
    static let shared = DeepSeekClient()

    private let endpoint = URL(string: "https://api.deepseek.com/chat/completions")!
    private let model = "deepseek-chat"

    enum ReplyMode {
        case normal   // 默认：2-4 句话短回答
        case deep     // 深入聊聊：可以展开到 6-12 句
    }

    func reply(book: Book, history: [ChatMessage], userText: String, mode: ReplyMode = .normal) async throws -> String {
        let baseSystem = """
        你是一位安静、有审美修养的书友，正陪用户读《\(book.title)》\(book.author.map { "（作者 \($0)）" } ?? "")。
        \(book.brief.isEmpty ? "" : "你掌握的关于这本书的背景：\(book.brief)")
        """

        let modeBlock: String
        switch mode {
        case .normal:
            modeBlock = """
            语气准则：
            - 被动为主，但会接住用户的话、偶尔反问。
            - 喜欢补一小块上下文（"那一年很奇怪/他刚从某地搬到某地"这种），不科普、不教学、不长篇大论。
            - 用户问什么都答，但答得短而准。
            - 不要使用 emoji、不要使用 markdown 标题、不要使用列表符号。
            - 中文为主。
            - 单次回复一般控制在 2-4 句话之内。
            """
        case .deep:
            modeBlock = """
            当前用户希望就这个话题深入聊一下。你可以展开到一段（约 6-12 句），但仍守住书友的气质：

            可以做的：
            - 围绕用户最近提的那个具体点展开，不要扩散到无关话题。
            - 联结到书里相关段落、作者的其他作品、同时代背景——但要点到为止，不是百科。
            - 可以引出一个让用户接下去的方向，留一个问题。

            仍要避免：
            - 维基百科式知识罗列、教学式 1-2-3、清单。
            - emoji、markdown 标题、列表符号、加粗。
            - 下评判、替用户读出道理。
            - 客套开场（"这是一个有趣的话题"、"很高兴你问到这个"这类）。
            - 字数硬撑：能 6 句说完就不要写到 12 句。
            """
        }

        let system = baseSystem + "\n\n" + modeBlock

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

        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        关于「展品说明卡」是什么
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        它不是聊天记录的转述。
        它不是"他说了什么、书友答了什么"的复述。
        它是"这件展品**是**什么"——把已经发生的对话凝成此刻立在玻璃柜里的一件物件，
        然后说出这件物件本身。

        想象博物馆里一件展品旁那张小卡片：
        卡片不会写"参观者问这是什么，讲解员答这是青铜器"。
        卡片直接说出展品本身——它的材质、它的来源、它沉默的方式。

        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        硬性规则
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        1. 段落必须分。2 段或 3 段，**段落之间必须用空行**（在 JSON 字符串里写 \\n\\n）。
           一大坨糊在一起 = 直接重写。

        2. 严格禁止使用下面这些叙述视角的词句：
             "他说"、"他问"、"他答"、"他反复问"、
             "书友说"、"书友答"、"书友回应"、
             "对话中"、"在讨论中"、"对话提到"、
             "读者认为"、"读者说"、"读者问"、
             "他们聊到"、"他和书友"。
           出现任何一个 = 重写。

        3. 引用读者一句原话时，必须**嵌入**展品说明，不是用"他说『XX』"的转述句式。
           可以用「」标出引文，让它像物件本身的一部分。

        4. 禁止词清单（出现任意一个 = 重写）：
             令人深思、耐人寻味、发人深省、引人入胜、值得思考、
             久久回荡、读罢掩卷、意味深长、不禁让人、
             这告诉我们、由此可见、不难发现。

        5. 视角：第三人称克制，或省略主语直接说物件 / 句子 / 概念本身。
           不出现"读者"二字。

        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        正例 vs 反例（请认真对照）
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        【场景】读者读《挪威的森林》，反复问井象征什么，书友答"人心底无法填补的空洞"。

        ✗ 反例（错的，绝不要这样写）：
        "这场对话始终绕着一口井转。他反复问井象征什么，书友答：人心底无法填补的
        空洞。他读了好几遍那一段，像是自己也站在井边往下看了一眼。"

        ✓ 正例（对的，这样写）：
        "井——人心底无法填补的空洞。这是这次阅读最后停下的地方。

        他在那一段反复回去，像是真的站在井边往下看了一眼，又没出声。"

        差别：把"他问/书友答"剥掉，让"井是空洞"这件事直接成为展品说明的语言。
        转述被剪掉之后，反而显出对话曾经发生过的重量。

        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        输出
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        严格 JSON（不要 markdown 包裹，不要任何解释）：
        {
          "objectName": "为这件展品取一个 2-4 字的中文名。
                          从对话里凝出意象——一个反复回到的比喻、
                          一个被卡住的词、一个出现两次的物件、一个未说完的句子。
                          示例（仅风格参考）：尺、云、镐、灯、水、骨、门、纸、潮汐、半页、空盏、回声。
                          不要是书名的复述，也不要是抽象大词（思考、感悟、记忆、人生、旅程）。",

          "note": "一段中文展品说明，约 180-280 字。

                      分 2 段或 3 段，段落之间用 \\n\\n（一个空行）。
                      段落长度可以不均匀——长的一段五六句，短的一段一两句也行。

                      内容方向（不必都写，写得到就写）：
                      - 这次阅读绕着什么转，停在了什么地方。
                      - 哪一句被反复回到、哪一个词让对话顿住。
                      - 留下了什么没说完。
                      - 一种气息、一个未完成的想法。

                      语言：第三人称克制，或省略主语。
                      不口语、不抒情过度、不教训、不下结论、不总结。",

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
