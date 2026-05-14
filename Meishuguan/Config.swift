import Foundation

enum Config {
    static let anthropicKey: String = secret("ANTHROPIC_API_KEY")
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
