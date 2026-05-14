import Foundation

enum Config {
    static let anthropicKey: String = secret("ANTHROPIC_API_KEY")

    /// 可选。填了就走 Replicate flux-schnell（~$0.003/张），不填走免费 Pollinations。
    static let replicateToken: String = secret("REPLICATE_API_TOKEN")

    /// 可选。未来真做 3D 物件时用。
    static let meshyKey: String = secret("MESHY_API_KEY")

    static let claudeModel = "claude-opus-4-7"
    static let anthropicVersion = "2023-06-01"

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
