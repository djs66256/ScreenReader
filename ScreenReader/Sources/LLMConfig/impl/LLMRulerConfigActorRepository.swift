import Foundation

actor LLMRulerConfigActorRepository: LLMRulerConfigRepository {
    private let storageFileURL: URL
    private let defaultTemplatesURL = StoragePath.templatesBaseDirectory
        .appendingPathComponent("DefaultRulers.json")
    
    init() {
        let rulersDirectory = StoragePath.configsDirectory
            .appendingPathComponent("Rulers")
        try? FileManager.default.createDirectory(at: rulersDirectory, withIntermediateDirectories: true)
        storageFileURL = rulersDirectory.appendingPathComponent("Rulers.json")
        
        // 检查是否是首次启动
        if !FileManager.default.fileExists(atPath: storageFileURL.path) {
            // 从模板加载默认配置
            if let defaultRulers = loadDefaultRulers() {
                saveRulers(defaultRulers)
            }
        }
    }
    
    private func loadDefaultRulers() -> [LLMRulerConfig]? {
        guard let data = try? Data(contentsOf: defaultTemplatesURL) else { return nil }
        return try? JSONDecoder().decode([LLMRulerConfig].self, from: data)
    }
    
    func getAllRulers() async -> [LLMRulerConfig] {
        guard let data = try? Data(contentsOf: storageFileURL) else { return [] }
        return (try? JSONDecoder().decode([LLMRulerConfig].self, from: data)) ?? []
    }
    
    func getRuler(id: String) async -> LLMRulerConfig? {
        let rulers = await getAllRulers()
        return rulers.first { $0.id == id }
    }
    
    func createRuler(ruler: LLMRulerConfig) async -> LLMRulerConfig {
        var rulers = await getAllRulers()
        rulers.append(ruler)
        saveRulers(rulers)
        return ruler
    }
    
    func updateRuler(ruler: LLMRulerConfig) async -> Bool {
        var rulers = await getAllRulers()
        guard let index = rulers.firstIndex(where: { $0.id == ruler.id }) else { return false }
        rulers[index] = ruler
        saveRulers(rulers)
        return true
    }
    
    func deleteRuler(id: String) async {
        var rulers = await getAllRulers()
        rulers.removeAll { $0.id == id }
        saveRulers(rulers)
    }
    
    private func saveRulers(_ rulers: [LLMRulerConfig]) {
        let data = try? JSONEncoder().encode(rulers)
        try? data?.write(to: storageFileURL)
    }
}