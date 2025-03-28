import Foundation
public struct LLMProviderConfig: Identifiable, Codable, Hashable {
    public let id: String
    public let name: String
    public var apiKey: String?
    public var defaultBaseURL: String?
    public var supportedModelIDs: [String]  // 改为存储模型ID

    // 从JSON文件加载所有Provider
    public static func loadProviders() -> [LLMProviderConfig] {
        guard let url = Bundle.main.url(forResource: "providers", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let providers = try? JSONDecoder().decode([LLMProviderConfig].self, from: data) else {
            return []
        }
        return providers
    }
    
}
