import Foundation

struct ChatModeConfig: Codable, Identifiable, Hashable, Equatable {
    var id: String
    var name: String
    var provider: LLMProviderConfig?
    var model: LLMModelConfig?
    var rules: [LLMRuleConfig]
}

protocol ChatModeConfigRepository {
    func getAllChatModes() async -> [ChatModeConfig]
    func getChatMode(id: String) async -> ChatModeConfig?
    func createChatMode(config: ChatModeConfig) async -> ChatModeConfig
    func updateChatMode(config: ChatModeConfig) async -> Bool
    func deleteChatMode(id: String) async
}

extension Notification.Name {
    static let chatModeConfigChanged = Notification.Name("ChatModeConfigChanged")
}
