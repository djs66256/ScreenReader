import Foundation

struct LLMProviderConfigTemplate: Codable {
    var id: String
    var name: String
    var defaultBaseURL: String?
}

protocol LLMProviderConfigTemplateRepository {
    func getAllConfigTemplates() async -> [LLMProviderConfigTemplate]
}

struct LLMProviderConfig: Codable {
    var id: String
    var name: String
    var defaultBaseURL: String?
    var apiKey: String?
    var supportedModelIDs: [String]

    init(id: String, name: String, defaultBaseURL: String?, apiKey: String?, supportedModelIDs: [String]) {
        self.id = id
        self.name = name
        self.defaultBaseURL = defaultBaseURL
        self.apiKey = apiKey
        self.supportedModelIDs = supportedModelIDs
    }

    init(template: LLMProviderConfigTemplate, apiKey: String?) {
        self.id = template.id
        self.name = template.name
        self.defaultBaseURL = template.defaultBaseURL
        self.apiKey = apiKey
        self.supportedModelIDs = []
    }
}

protocol LLMProviderConfigRepository {
    func getAllConfigs() async -> [LLMProviderConfig]
    func getConfig(id: String) async -> LLMProviderConfig?
    func createConfig(config: LLMProviderConfig) async -> LLMProviderConfig
    func updateConfig(config: LLMProviderConfig) async -> Bool
    func deleteConfig(id: String) async
}