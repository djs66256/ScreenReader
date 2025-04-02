import Foundation

struct LLMProviderConfig: Codable, Equatable, Identifiable, Hashable {
    var id: String
    var type: String
    var name: String
    var defaultBaseURL: String?
    var apiKey: String?
    var supportedModelIDs: [String]

    init(id: String, type: String, name: String, defaultBaseURL: String?, apiKey: String?, supportedModelIDs: [String]) {
        self.id = id
        self.type = type
        self.name = name
        self.defaultBaseURL = defaultBaseURL
        self.apiKey = apiKey
        self.supportedModelIDs = supportedModelIDs
    }
}

protocol LLMProviderConfigRepository {
    func getAllTemplates() async -> [LLMProviderConfig]
    func getAllConfigs() async -> [LLMProviderConfig]
    func getConfig(id: String) async -> LLMProviderConfig?
    func createConfig(config: LLMProviderConfig) async -> LLMProviderConfig
    func updateConfig(config: LLMProviderConfig) async -> Bool
    func deleteConfig(id: String) async
}

extension Notification.Name {
    static let llmProviderConfigChanged = Notification.Name("LLMProviderConfigChanged")
}
