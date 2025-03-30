import Foundation

struct LLMRuleConfig: Codable, Hashable, Identifiable, Equatable {
    var id: String
    var name: String
    var systemPrompt: String?
}

protocol LLMRuleConfigRepository {
    func getAllRules() async -> [LLMRuleConfig]
    func getRule(id: String) async -> LLMRuleConfig?
    func createRule(rule: LLMRuleConfig) async -> LLMRuleConfig
    func updateRule(rule: LLMRuleConfig) async -> Bool
    func deleteRule(id: String) async
}

extension Notification.Name {
    static let llmRuleConfigChanged = Notification.Name("LLMRuleConfigChanged")
}
