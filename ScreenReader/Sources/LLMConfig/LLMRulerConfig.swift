import Foundation

struct LLMRulerConfig: Codable {
    var id: String
    var name: String
    var systemPrompt: String?
}

protocol LLMRulerConfigRepository {
    func getAllRulers() async -> [LLMRulerConfig]
    func getRuler(id: String) async -> LLMRulerConfig?
    func createRuler(ruler: LLMRulerConfig) async -> LLMRulerConfig
    func updateRuler(ruler: LLMRulerConfig) async -> Bool
    func deleteRuler(id: String) async
}