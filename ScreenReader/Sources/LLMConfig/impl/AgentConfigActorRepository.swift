import Foundation

actor AgentConfigActorRepository: AgentConfigRepository {
    private let storageFileURL: URL
    private let providerRepository: any LLMProviderConfigRepository
    private let ruleRepository: any LLMRuleConfigRepository
    private var observers: [NSObjectProtocol] = []
    private var cachedAgents: [AgentConfig]?
    private let defaultTemplatesURL = StoragePath.Agents.templates // 更新模板路径

    init(
        providerRepository: any LLMProviderConfigRepository = LLMProviderConfigActorRepository(),
        ruleRepository: any LLMRuleConfigRepository = LLMRuleConfigActorRepository()
    ) {
        let agentsDirectory = StoragePath.configsDirectory
            .appendingPathComponent("Agents")
        try? FileManager.default.createDirectory(at: agentsDirectory, withIntermediateDirectories: true)
        storageFileURL = agentsDirectory.appendingPathComponent("Agents.json")
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

    func getAllAgents() async -> [AgentConfig] {
        if let cached = cachedAgents, !cached.isEmpty {
            return cached
        }
        
        // 加载用户保存的配置
        let savedModes: [AgentConfig]
        if let data = try? Data(contentsOf: storageFileURL) {
            savedModes = (try? JSONDecoder().decode([AgentConfig].self, from: data)) ?? []
        } else {
            savedModes = []
        }
        
        // 如果用户配置为空，则加载默认模板
        if savedModes.isEmpty {
            let defaultModes = loadDefaultTemplates() ?? []
            cachedAgents = defaultModes
            return defaultModes
        }
        
        cachedAgents = savedModes
        return savedModes
    }
    
    private func loadDefaultTemplates() -> [AgentConfig]? {
        guard let data = try? Data(contentsOf: defaultTemplatesURL) else { return nil }
        return (try? JSONDecoder().decode([AgentConfig].self, from: data)) ?? []
    }

    private func handleRuleChange() async {
        var agents = await getAllAgents()
        var changed = false

        for i in agents.indices {
            let originalCount = agents[i].rules.count
            agents[i].rules = await withTaskGroup(of: LLMRuleConfig?.self) { group in
                for rule in agents[i].rules {
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

            if agents[i].rules.count != originalCount {
                changed = true
            }
        }

        if changed {
            saveAgents(agents)
        }
    }

    private func handleProviderChange() async {
        var agents = await getAllAgents()
        var changed = false

        for i in agents.indices {
            if let providerId = agents[i].provider?.id {
                if await providerRepository.getConfig(id: providerId) == nil {
                    agents[i].provider = nil
                    agents[i].model = nil
                    changed = true
                }
            }
        }

        if changed {
            saveAgents(agents)
        }
    }

    func getAgent(id: String) async -> AgentConfig? {
        let agents = await getAllAgents()
        return agents.first { $0.id == id }
    }

    func createAgent(config: AgentConfig) async -> AgentConfig {
        var agents = await getAllAgents()
        agents.append(config)
        saveAgents(agents)
        return config
    }

    func updateAgent(config: AgentConfig) async -> Bool {
        var agents = await getAllAgents()
        guard let index = agents.firstIndex(where: { $0.id == config.id }) else { return false }
        agents[index] = config
        saveAgents(agents)
        return true
    }

    func deleteAgent(id: String) async {
        var agents = await getAllAgents()
        agents.removeAll { $0.id == id }
        saveAgents(agents)
    }

    private func saveAgents(_ agents: [AgentConfig]) {
        let data = try? JSONEncoder().encode(agents)
        try? data?.write(to: storageFileURL)
        cachedAgents = agents
        NotificationCenter.default.post(name: .agentConfigChanged, object: nil)
    }
}
