import Foundation

struct ChatModeConfig: Codable {
    var provider: LLMProviderConfig
    var model: LLMModelConfig
    var rules: [LLMRuleConfig]
}

protocol ChatModeConfigRepository {
    func getAllChatModes() async -> [ChatModeConfig]
    func getChatMode(id: String) async -> ChatModeConfig?
    func createChatMode(config: ChatModeConfig) async -> ChatModeConfig
    func updateChatMode(config: ChatModeConfig) async -> Bool
    func deleteChatMode(id: String) async
}