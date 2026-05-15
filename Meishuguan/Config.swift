import Foundation

enum Config {
    /// 阿里云 DashScope（Qwen-VL）— 用于书封 Vision 识别。
    static let dashscopeKey: String = secret("DASHSCOPE_API_KEY")

    /// 文本对话/总结走 DeepSeek（OpenAI 兼容、超便宜）。
    static let deepseekKey: String = secret("DEEPSEEK_API_KEY")

    /// 可选。填了就走 Replicate flux-schnell（~$0.003/张），不填走免费 Pollinations。
    static let replicateToken: String = secret("REPLICATE_API_TOKEN")

    /// 可选。未来真做 3D 物件时用。
    static let meshyKey: String = secret("MESHY_API_KEY")

    static let qwenVisionModel = "qwen-vl-plus"

    private static func secret(_ key: String) -> String {
        guard
            let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
            let data = try? Data(contentsOf: url),
            let dict = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
            let value = dict[key] as? String, !value.isEmpty
        else {
            return ""
        }
        return value
    }
}
