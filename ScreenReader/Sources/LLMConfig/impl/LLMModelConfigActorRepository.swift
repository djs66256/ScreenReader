import Foundation

actor LLMModelConfigActorRepository: LLMModelConfigRepository {
    private let storageFileURL: URL
    
    init() {
        let modelsDirectory = StoragePath.configsDirectory
            .appendingPathComponent("Models")
        try? FileManager.default.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)
        storageFileURL = modelsDirectory.appendingPathComponent("Models.json")
    }
    
    func getAllConfigs() async -> [LLMModelConfig] {
        guard let data = try? Data(contentsOf: storageFileURL) else { return [] }
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
    }
}