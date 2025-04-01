import Foundation

actor LLMRuleConfigActorRepository: LLMRuleConfigRepository {
    private let notificationCenter = NotificationCenter.default
    private let storageFileURL: URL
    private let defaultTemplatesURL = StoragePath.Rules.templates
    private var cachedRules: [LLMRuleConfig]? // 新增内存缓存
    
    init() {
        let rulesDirectory = StoragePath.configsDirectory
            .appendingPathComponent("Rules")
        try? FileManager.default.createDirectory(at: rulesDirectory, withIntermediateDirectories: true)
        storageFileURL = rulesDirectory.appendingPathComponent("Rules.json")
    }
    
    func getAllRules() async -> [LLMRuleConfig] {
        if let cached = cachedRules, !cached.isEmpty {
            return cached
        }
        
        // 加载用户保存的配置
        let savedRules: [LLMRuleConfig]
        if let data = try? Data(contentsOf: storageFileURL) {
            savedRules = (try? JSONDecoder().decode([LLMRuleConfig].self, from: data)) ?? []
        } else {
            savedRules = []
        }
        
        // 如果用户配置为空，则直接返回默认配置
        if savedRules.isEmpty {
            let defaultRules = loadDefaultRules() ?? []
            cachedRules = defaultRules
            return defaultRules
        }
        
        // 否则缓存并返回用户配置
        cachedRules = savedRules
        return savedRules
    }

    private func loadDefaultRules() -> [LLMRuleConfig]? {
        guard let data = try? Data(contentsOf: defaultTemplatesURL) else { return nil }
        return try? JSONDecoder().decode([LLMRuleConfig].self, from: data)
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
        if let index = rules.firstIndex(where: { $0.id == rule.id }) {
            rules[index] = rule
        } else {
            rules.append(rule)
        }
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
        cachedRules = rules // 更新缓存
        notificationCenter.post(name: .llmRuleConfigChanged, object: nil)
    }
}