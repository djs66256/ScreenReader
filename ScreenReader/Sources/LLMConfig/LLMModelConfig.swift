import Foundation

struct LLMModelConfigTemplate: Codable {
    var modelName: String
    var systemPrompt: String?
    var maxTokens: Int
    var temperature: Double
    var topP: Double
    var presencePenalty: Double
    var frequencyPenalty: Double
    var stopWords: [String]
}

protocol LLMModelConfigTemplateRepository {
    func getAllModelTemplates() async -> [LLMModelConfigTemplate]
}

struct LLMModelConfig: Codable {
    var modelName: String
    var systemPrompt: String?
    var maxTokens: Int
    var temperature: Double
    var topP: Double
    var presencePenalty: Double
    var frequencyPenalty: Double
    var stopWords: [String]
}

protocol LLMModelConfigRepository {
    func getAllConfigs() async -> [LLMModelConfig]
    func getConfig(modelName: String) async -> LLMModelConfig?
    func createConfig(config: LLMModelConfig) async -> LLMModelConfig
    func updateConfig(config: LLMModelConfig) async -> Bool
    func deleteConfig(modelName: String) async
}