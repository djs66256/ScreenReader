import Foundation

actor ChatModeConfigActorRepository: ChatModeConfigRepository {
    private let storageFileURL: URL
    
    init() {
        let chatModesDirectory = StoragePath.configsDirectory
            .appendingPathComponent("ChatModes")
        try? FileManager.default.createDirectory(at: chatModesDirectory, withIntermediateDirectories: true)
        storageFileURL = chatModesDirectory.appendingPathComponent("ChatModes.json")
    }
    
    func getAllChatModes() async -> [ChatModeConfig] {
        guard let data = try? Data(contentsOf: storageFileURL) else { return [] }
        return (try? JSONDecoder().decode([ChatModeConfig].self, from: data)) ?? []
    }
    
    func getChatMode(id: String) async -> ChatModeConfig? {
        let modes = await getAllChatModes()
        return modes.first { $0.provider.id == id }
    }
    
    func createChatMode(config: ChatModeConfig) async -> ChatModeConfig {
        var modes = await getAllChatModes()
        modes.append(config)
        saveModes(modes)
        return config
    }
    
    func updateChatMode(config: ChatModeConfig) async -> Bool {
        var modes = await getAllChatModes()
        guard let index = modes.firstIndex(where: { $0.provider.id == config.provider.id }) else { return false }
        modes[index] = config
        saveModes(modes)
        return true
    }
    
    func deleteChatMode(id: String) async {
        var modes = await getAllChatModes()
        modes.removeAll { $0.provider.id == id }
        saveModes(modes)
    }
    
    private func saveModes(_ modes: [ChatModeConfig]) {
        let data = try? JSONEncoder().encode(modes)
        try? data?.write(to: storageFileURL)
    }
}