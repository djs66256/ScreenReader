import Foundation

struct AgentConfig: Codable, Identifiable, Hashable, Equatable {
    var id: String
    var name: String
    var provider: LLMProviderConfig?
    var model: LLMModelConfig?
    var systemPrompt: String?
    var rules: [LLMRuleConfig]
}

protocol AgentConfigRepository {
    func getAllAgents() async -> [AgentConfig]
    func getAgent(id: String) async -> AgentConfig?
    func createAgent(config: AgentConfig) async -> AgentConfig
    func updateAgent(config: AgentConfig) async -> Bool
    func deleteAgent(id: String) async
}

extension Notification.Name {
    static let agentConfigChanged = Notification.Name("AgentConfigChanged")
}
