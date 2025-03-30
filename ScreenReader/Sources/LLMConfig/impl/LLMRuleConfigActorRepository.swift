import Foundation

actor LLMRuleConfigActorRepository: LLMRuleConfigRepository {
    private let storageFileURL: URL
    private let defaultTemplatesURL = StoragePath.templatesBaseDirectory
        .appendingPathComponent("DefaultRules.json")
    
    init() {
        let rulesDirectory = StoragePath.configsDirectory
            .appendingPathComponent("Rules")
        try? FileManager.default.createDirectory(at: rulesDirectory, withIntermediateDirectories: true)
        storageFileURL = rulesDirectory.appendingPathComponent("Rules.json")
        
        // 检查是否是首次启动
        if !FileManager.default.fileExists(atPath: storageFileURL.path) {
            // 从模板加载默认配置
            if let defaultRules = loadDefaultRules() {
                saveRules(defaultRules)
            }
        }
    }
    
    private func loadDefaultRules() -> [LLMRuleConfig]? {
        guard let data = try? Data(contentsOf: defaultTemplatesURL) else { return nil }
        return try? JSONDecoder().decode([LLMRuleConfig].self, from: data)
    }
    
    func getAllRules() async -> [LLMRuleConfig] {
        guard let data = try? Data(contentsOf: storageFileURL) else { return [] }
        return (try? JSONDecoder().decode([LLMRuleConfig].self, from: data)) ?? []
    }
    
    func getRule(id: String) async -> LLMRuleConfig? {
        let rules = await getAllRules()
        return rules.first { $0.id == id }
    }
    
    func createRule(rule: LLMRuleConfig) async -> LLMRuleConfig {
        var rules = await getAllRules()
        rules.append(rule)
        saveRules(rules)
        return rule
    }
    
    func updateRule(rule: LLMRuleConfig) async -> Bool {
        var rules = await getAllRules()
        guard let index = rules.firstIndex(where: { $0.id == rule.id }) else { return false }
        rules[index] = rule
        saveRules(rules)
        return true
    }
    
    func deleteRule(id: String) async {
        var rules = await getAllRules()
        rules.removeAll { $0.id == id }
        saveRules(rules)
    }
    
    private func saveRules(_ rules: [LLMRuleConfig]) {
        let data = try? JSONEncoder().encode(rules)
        try? data?.write(to: storageFileURL)
    }
}