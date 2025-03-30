import Foundation

actor ChatModeConfigActorRepository: ChatModeConfigRepository {
    private let storageFileURL: URL
    private let providerRepository: any LLMProviderConfigRepository
    private let ruleRepository: any LLMRuleConfigRepository
    private var observers: [NSObjectProtocol] = []  // 新增：存储观察者引用

    init(
        providerRepository: any LLMProviderConfigRepository = LLMProviderConfigActorRepository(),
        ruleRepository: any LLMRuleConfigRepository = LLMRuleConfigActorRepository()
    ) {
        let chatModesDirectory = StoragePath.configsDirectory
            .appendingPathComponent("ChatModes")
        try? FileManager.default.createDirectory(at: chatModesDirectory, withIntermediateDirectories: true)
        storageFileURL = chatModesDirectory.appendingPathComponent("ChatModes.json")
        self.providerRepository = providerRepository
        self.ruleRepository = ruleRepository
        setupObservers()
    }

    deinit {
        // 新增：在析构时移除所有观察者
        observers.forEach { observer in
            NotificationCenter.default.removeObserver(observer)
        }
    }

    private func setupObservers() {
        // 修改：存储观察者引用
        let providerObserver = NotificationCenter.default.addObserver(
            forName: .llmProviderConfigChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task {
                await self?.handleProviderChange()
            }
        }

        let ruleObserver = NotificationCenter.default.addObserver(
            forName: .llmRuleConfigChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task {
                await self?.handleRuleChange()
            }
        }

        observers.append(contentsOf: [providerObserver, ruleObserver])
    }

    func getAllChatModes() async -> [ChatModeConfig] {
        guard let data = try? Data(contentsOf: storageFileURL) else { return [] }
        var modes = (try? JSONDecoder().decode([ChatModeConfig].self, from: data)) ?? []

        // Check and update providers
        for i in modes.indices {
            if let providerId = modes[i].provider?.id {
                if await providerRepository.getConfig(id: providerId) == nil {
                    modes[i].provider = nil
                    modes[i].model = nil
                }
            }

            // Async rule filtering
            modes[i].rules = await withTaskGroup(of: LLMRuleConfig?.self) { group in
                for rule in modes[i].rules {
                    group.addTask {
                        await self.ruleRepository.getRule(id: rule.id) != nil ? rule : nil
                    }
                }

                var validRules: [LLMRuleConfig] = []
                for await rule in group {
                    if let rule = rule {
                        validRules.append(rule)
                    }
                }
                return validRules
            }
        }

        return modes
    }

    private func handleRuleChange() async {
        var modes = await getAllChatModes()
        var changed = false

        for i in modes.indices {
            let originalCount = modes[i].rules.count
            modes[i].rules = await withTaskGroup(of: LLMRuleConfig?.self) { group in
                for rule in modes[i].rules {
                    group.addTask {
                        await self.ruleRepository.getRule(id: rule.id) != nil ? rule : nil
                    }
                }

                var validRules: [LLMRuleConfig] = []
                for await rule in group {
                    if let rule = rule {
                        validRules.append(rule)
                    }
                }
                return validRules
            }

            if modes[i].rules.count != originalCount {
                changed = true
            }
        }

        if changed {
            saveModes(modes)
        }
    }

    private func handleProviderChange() async {
        var modes = await getAllChatModes()
        var changed = false

        for i in modes.indices {
            if let providerId = modes[i].provider?.id {
                if await providerRepository.getConfig(id: providerId) == nil {
                    modes[i].provider = nil
                    modes[i].model = nil
                    changed = true
                }
            }
        }

        if changed {
            saveModes(modes)
        }
    }

    func getChatMode(id: String) async -> ChatModeConfig? {
        let modes = await getAllChatModes()
        return modes.first { $0.id == id }
    }

    func createChatMode(config: ChatModeConfig) async -> ChatModeConfig {
        var modes = await getAllChatModes()
        modes.append(config)
        saveModes(modes)
        return config
    }

    func updateChatMode(config: ChatModeConfig) async -> Bool {
        var modes = await getAllChatModes()
        guard let index = modes.firstIndex(where: { $0.id == config.id }) else { return false }
        modes[index] = config
        saveModes(modes)
        return true
    }

    func deleteChatMode(id: String) async {
        var modes = await getAllChatModes()
        modes.removeAll { $0.id == id }
        saveModes(modes)
    }

    private func saveModes(_ modes: [ChatModeConfig]) {
        let data = try? JSONEncoder().encode(modes)
        try? data?.write(to: storageFileURL)
        NotificationCenter.default.post(name: .chatModeConfigChanged, object: nil)
    }
}
