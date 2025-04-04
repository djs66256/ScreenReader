import Foundation

struct LLMModelConfig: Codable, Equatable, Hashable {
    var modelName: String
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
