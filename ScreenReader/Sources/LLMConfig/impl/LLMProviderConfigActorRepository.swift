import Foundation

actor LLMProviderConfigActorRepository: LLMProviderConfigRepository {
    private let storageFileURL: URL
    
    init() {
        let providersDirectory = StoragePath.configsDirectory
            .appendingPathComponent("Providers")
        try? FileManager.default.createDirectory(at: providersDirectory, withIntermediateDirectories: true)
        storageFileURL = providersDirectory.appendingPathComponent("Providers.json")
    }
    
    func getAllConfigs() async -> [LLMProviderConfig] {
        guard let data = try? Data(contentsOf: storageFileURL) else { return [] }
        return (try? JSONDecoder().decode([LLMProviderConfig].self, from: data)) ?? []
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
    }
}