import Foundation

actor LLMModelConfigActorRepository: LLMModelConfigRepository {
    private let storageFileURL: URL
    private var cachedConfigs: [LLMModelConfig]? // 新增内存缓存
    private let defaultTemplatesURL = StoragePath.Models.templates // 新增默认配置路径
    
    init() {
        let modelsDirectory = StoragePath.configsDirectory
            .appendingPathComponent("Models")
        try? FileManager.default.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)
        storageFileURL = modelsDirectory.appendingPathComponent("Models.json")
    }
    
    func getAllConfigs() async -> [LLMModelConfig] {
        if let cached = cachedConfigs, !cached.isEmpty {
            return cached
        }
        
        // 加载用户保存的配置
        let savedConfigs: [LLMModelConfig]
        if let data = try? Data(contentsOf: storageFileURL) {
            savedConfigs = (try? JSONDecoder().decode([LLMModelConfig].self, from: data)) ?? []
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
    
    private func loadDefaultConfigs() -> [LLMModelConfig]? {
        guard let data = try? Data(contentsOf: defaultTemplatesURL) else { return nil }
        return (try? JSONDecoder().decode([LLMModelConfig].self, from: data)) ?? []
    }
    
    func getConfig(modelName: String) async -> LLMModelConfig? {
        let configs = await getAllConfigs()
        return configs.first { $0.modelName == modelName }
    }
    
    func createConfig(config: LLMModelConfig) async -> LLMModelConfig {
        var configs = await getAllConfigs()
        configs.append(config)
        saveConfigs(configs)
        return config
    }
    
    func updateConfig(config: LLMModelConfig) async -> Bool {
        var configs = await getAllConfigs()
        guard let index = configs.firstIndex(where: { $0.modelName == config.modelName }) else { return false }
        configs[index] = config
        saveConfigs(configs)
        return true
    }
    
    func deleteConfig(modelName: String) async {
        var configs = await getAllConfigs()
        configs.removeAll { $0.modelName == modelName }
        saveConfigs(configs)
    }
    
    private func saveConfigs(_ configs: [LLMModelConfig]) {
        let data = try? JSONEncoder().encode(configs)
        try? data?.write(to: storageFileURL)
        cachedConfigs = configs // 更新缓存
    }
}