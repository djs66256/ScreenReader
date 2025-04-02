import SwiftUI

struct AgentConfigRepositoryKey: EnvironmentKey {
    static let defaultValue: any AgentConfigRepository = MockAgentConfigRepository()
}

extension EnvironmentValues {
    var agentConfigRepository: any AgentConfigRepository {
        get { self[AgentConfigRepositoryKey.self] }
        set { self[AgentConfigRepositoryKey.self] = newValue }
    }
}

struct AgentSettingsView: View {
    @Environment(\.agentConfigRepository) private var repository
    @State private var agents: [AgentConfig] = []
    @State private var selection: AgentConfig?
    @State private var observer: Any?

    var body: some View {
        SidebarSettingsView(
            items: $agents,
            selection: $selection,
            leftContent: { agent in
                HStack {
                    Image(systemName: "message")
                    Text(agent.name)
                }
            },
            rightContent: { agent in
                AgentDetailView(agentConfig: agent)
            },
            bottomContent: {
                Button(action: addNewAgent) {
                    HStack {
                        Spacer()
                        Image(systemName: "plus")
                            .frame(width: 40)
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
            }
        )
        .onAppear {
            loadAgents()
            setupObserver()
        }
        .onDisappear {
            if let observer = observer {
                NotificationCenter.default.removeObserver(observer)
            }
        }
    }

    private func setupObserver() {
        observer = NotificationCenter.default.addObserver(
            forName: .agentConfigChanged,
            object: nil,
            queue: .main
        ) { _ in
            loadAgents()
        }
    }

    private func loadAgents() {
        Task {
            let loadedAgents = await repository.getAllAgents()
            DispatchQueue.main.async {
                let currentSelectionExists = loadedAgents.contains { $0.id == self.selection?.id }
                self.agents = loadedAgents
                if !currentSelectionExists {
                    self.selection = loadedAgents.first
                }
            }
        }
    }

    private func addNewAgent() {
        let newAgent = AgentConfig(
            id: UUID().uuidString,
            name: "新代理",
            provider: nil,
            model: nil,
            rules: []
        )

        Task {
            let createdAgent = await repository.createAgent(config: newAgent)
            DispatchQueue.main.async {
                self.agents.append(createdAgent)
                self.selection = createdAgent
            }
        }
    }
}

struct AgentDetailView: View {
    @State var agentConfig: AgentConfig
    @Environment(\.agentConfigRepository) private var repository
    @Environment(\.llmProviderConfigRepository) private var providerRepository
    @Environment(\.ruleConfigRepository) private var ruleRepository
    @State private var providers: [LLMProviderConfig] = []
    @State private var allRules: [LLMRuleConfig] = []
    @State private var isRulesExpanded: Bool = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 代理名称
                Text("代理名称")
                    .font(.title3)
                    .foregroundColor(.secondary)
                TextField("请输入代理名称", text: $agentConfig.name)
                    .textFieldStyle(.plain)
                    .padding(10)
                    .background(Color(.controlBackgroundColor))
                    .cornerRadius(6)

                // 修改提供商选择部分
                Text("提供商")
                    .font(.title3)
                    .foregroundColor(.secondary)
                Picker("选择提供商", selection: $agentConfig.provider) {
                    Text("无").tag(nil as LLMProviderConfig?)
                    ForEach(providers, id: \.id) { provider in
                        Text(provider.name).tag(provider as LLMProviderConfig?)
                    }
                }
                .pickerStyle(.menu)
                .onAppear {
                    Task {
                        let loadedProviders = await providerRepository.getAllConfigs()
                        DispatchQueue.main.async {
                            self.providers = loadedProviders
                        }
                    }
                }

                // 添加模型名称输入
                Text("模型名称")
                    .font(.title3)
                    .foregroundColor(.secondary)
                TextField("请输入模型名称", text: Binding(
                    get: { agentConfig.model?.modelName ?? "" },
                    set: {
                        if agentConfig.model == nil {
                            agentConfig.model = LLMModelConfig(
                                modelName: $0,
                                maxTokens: 2048,
                                temperature: 0.7,
                                topP: 1.0,
                                presencePenalty: 0.0,
                                frequencyPenalty: 0.0,
                                stopWords: []
                            )
                        } else {
                            agentConfig.model?.modelName = $0
                        }
                    }
                ))
                .textFieldStyle(.plain)
                .padding(10)
                .background(Color(.controlBackgroundColor))
                .cornerRadius(6)

                // 添加系统提示词输入
                Text("系统提示词")
                    .font(.title3)
                    .foregroundColor(.secondary)
                TextEditor(text: Binding(
                    get: { agentConfig.model?.systemPrompt ?? "" },
                    set: {
                        if agentConfig.model == nil {
                            agentConfig.model = LLMModelConfig(
                                modelName: "",
                                systemPrompt: $0,
                                maxTokens: 2048,
                                temperature: 0.7,
                                topP: 1.0,
                                presencePenalty: 0.0,
                                frequencyPenalty: 0.0,
                                stopWords: []
                            )
                        } else {
                            agentConfig.model?.systemPrompt = $0
                        }
                    }
                ))
                .frame(minHeight: 80)
                .padding(10)
                .background(Color(.controlBackgroundColor))
                .cornerRadius(6)
                .scrollIndicators(.never)

                // 规则列表
                DisclosureGroup(isExpanded: $isRulesExpanded) {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(allRules, id: \.id) { rule in
                            HStack {
                                Toggle(isOn: Binding(
                                    get: { agentConfig.rules.contains(where: { $0.id == rule.id }) },
                                    set: { isSelected in
                                        if isSelected {
                                            agentConfig.rules.append(rule)
                                        } else {
                                            agentConfig.rules.removeAll { $0.id == rule.id }
                                        }
                                    }
                                )) {
                                    Text(rule.name)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .toggleStyle(.switch)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .padding(.vertical, 8)
                } label: {
                    Text("关联规则 (\(agentConfig.rules.count)/\(allRules.count))")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation {
                        isRulesExpanded.toggle()
                    }
                }
                .onAppear {
                    Task {
                        let loadedRules = await ruleRepository.getAllRules()
                        DispatchQueue.main.async {
                            self.allRules = loadedRules
                        }
                    }
                }

                HStack {
                    Button("保存") {
                        Task {
                            _ = await repository.updateAgent(config: agentConfig)
                        }
                    }
                    .controlSize(.large)
                    .buttonStyle(.borderedProminent)

                    Button("删除", role: .destructive) {
                        Task {
                            await repository.deleteAgent(id: agentConfig.id)
                        }
                    }
                    .controlSize(.large)
                    .buttonStyle(.bordered)
                }
            }
            .padding()
        }
    }
}

struct AgentSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            AgentSettingsView()
                .environment(\.agentConfigRepository, MockAgentConfigRepository())
                .environment(\.llmProviderConfigRepository, MockLLMProviderConfigRepository())
                .environment(\.ruleConfigRepository, MockRuleConfigRepository())

            //            AgentDetailView(
            //                agentConfig: AgentConfig(
            //                    id: "preview-agent",
            //                    name: "预览模式",
            //                    provider: LLMProviderConfig(
            //                        id: "preview-provider",
            //                        name: "OpenAI",
            //                        defaultBaseURL: "https://api.openai.com",
            //                        apiKey: nil,
            //                        supportedModelIDs: ["gpt-4"]
            //                    ),
            //                    model: LLMModelConfig(
            //                        id: "preview-model",
            //                        modelName: "GPT-4",
            //                        providerID: "preview-provider"
            //                    ),
            //                    rules: [
            //                        LLMRuleConfig(
            //                            id: "preview-rule",
            //                            name: "默认规则",
            //                            systemPrompt: "这是一个系统提示词示例"
            //                        )
            //                    ]
            //                )
            //            )
            //            .environment(\.agentConfigRepository, MockAgentConfigRepository())
            //            .environment(\.llmProviderConfigRepository, MockLLMProviderConfigRepository())
            //            .environment(\.ruleConfigRepository, MockRuleConfigRepository())
            //            .previewDisplayName("聊天模式详情预览")
        }
    }
}

class MockAgentConfigRepository: AgentConfigRepository {
    private var agents: [AgentConfig]

    init() {
        self.agents = []
    }

    func getAllAgents() async -> [AgentConfig] {
        agents
    }

    func getAgent(id: String) async -> AgentConfig? {
        agents.first { $0.id == id }
    }

    func createAgent(config: AgentConfig) async -> AgentConfig {
        agents.append(config)
        return config
    }

    func updateAgent(config: AgentConfig) async -> Bool {
        if let index = agents.firstIndex(where: { $0.id == config.id }) {
            agents[index] = config
        } else {
            agents.append(config)
        }
        return true
    }

    func deleteAgent(id: String) async {
        agents.removeAll { $0.id == id }
    }
}
