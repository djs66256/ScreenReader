import Foundation

actor LLMProviderConfigActorRepository: LLMProviderConfigRepository {
    private let storageFileURL: URL
    private var cachedConfigs: [LLMProviderConfig]?
    private let defaultTemplatesURL = StoragePath.Providers.templates // 新增基础配置路径
    
    init() {
        let providersDirectory = StoragePath.configsDirectory
            .appendingPathComponent("Providers")
        try? FileManager.default.createDirectory(at: providersDirectory, withIntermediateDirectories: true)
        storageFileURL = providersDirectory.appendingPathComponent("Providers.json")
    }
    
    func getAllConfigs() async -> [LLMProviderConfig] {
        if let cached = cachedConfigs, !cached.isEmpty {
            return cached
        }
        
        // 加载用户保存的配置
        let savedConfigs: [LLMProviderConfig]
        if let data = try? Data(contentsOf: storageFileURL) {
            savedConfigs = (try? JSONDecoder().decode([LLMProviderConfig].self, from: data)) ?? []
        } else {
            savedConfigs = []
        }
        
        // 如果用户配置为空，则直接返回默认配置
        if savedConfigs.isEmpty {
            let defaultConfigs = loadDefaultConfigs() ?? []
            cachedConfigs = defaultConfigs
            return defaultConfigs
        }
        
        // 否则缓存并返回用户配置
        cachedConfigs = savedConfigs
        return savedConfigs
    }

    private func loadDefaultConfigs() -> [LLMProviderConfig]? {
        guard let data = try? Data(contentsOf: defaultTemplatesURL) else { return nil }
        return (try? JSONDecoder().decode([LLMProviderConfig].self, from: data)) ?? []
    }
        
    func getAllTemplates() async -> [LLMProviderConfig] {
        return loadDefaultConfigs() ?? []
    }
    
    func getConfig(id: String) async -> LLMProviderConfig? {
        let configs = await getAllConfigs()
        return configs.first { $0.id == id }
    }
    
    func createConfig(config: LLMProviderConfig) async -> LLMProviderConfig {
        var configs = await getAllConfigs()
        configs.append(config)
        saveConfigs(configs)
        return config
    }
    
    func updateConfig(config: LLMProviderConfig) async -> Bool {
        var configs = await getAllConfigs()
        guard let index = configs.firstIndex(where: { $0.id == config.id }) else { return false }
        configs[index] = config
        saveConfigs(configs)
        return true
    }
    
    func deleteConfig(id: String) async {
        var configs = await getAllConfigs()
        configs.removeAll { $0.id == id }
        saveConfigs(configs)
    }
    
    private func saveConfigs(_ configs: [LLMProviderConfig]) {
        let data = try? JSONEncoder().encode(configs)
        try? data?.write(to: storageFileURL)
        cachedConfigs = configs // 更新缓存
        NotificationCenter.default.post(name: .llmProviderConfigChanged, object: nil)
    }
}
