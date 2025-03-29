import Foundation

public struct LLMModel: Identifiable, Codable, Hashable {
    public enum Capability: String, Codable, CaseIterable {
        case chat = "chat"
        case vision = "vision"
        case audio = "audio"
        case functionCalling = "functionCalling"
        case jsonMode = "jsonMode"
    }
    
    public let id: String
    public let name: String
    public let capabilities: [Capability]
    public let maxTokens: Int?
    public let defaultTemperature: Double?
    public let thinkToken: String?

    // 从JSON文件加载所有模型
    public static func loadModels() -> [LLMModel] {
        guard let url = Bundle.main.url(forResource: "models", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let models = try? JSONDecoder().decode([LLMModel].self, from: data) else {
            return []
        }
        return models
    }
    
    // 移除硬编码的静态模型实例和allModels
}
