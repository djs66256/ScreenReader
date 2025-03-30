import SwiftUI

struct ChatModeConfigRepositoryKey: EnvironmentKey {
    static let defaultValue: any ChatModeConfigRepository = MockChatModeConfigRepository()
}

extension EnvironmentValues {
    var chatModeConfigRepository: any ChatModeConfigRepository {
        get { self[ChatModeConfigRepositoryKey.self] }
        set { self[ChatModeConfigRepositoryKey.self] = newValue }
    }
}

struct ChatModeSettingsView: View {
    @Environment(\.chatModeConfigRepository) private var repository
    @State private var chatModes: [ChatModeConfig] = []
    @State private var selection: ChatModeConfig?
    @State private var observer: Any?

    var body: some View {
        SidebarSettingsView(
            items: $chatModes,
            selection: $selection,
            leftContent: { chatMode in
                HStack {
                    Image(systemName: "message")
                    Text(chatMode.name)
                }
            },
            rightContent: { chatMode in
                ChatModeDetailView(chatMode: chatMode)
            },
            bottomContent: {
                Button(action: addNewChatMode) {
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
            loadChatModes()
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
            forName: .chatModeConfigChanged,
            object: nil,
            queue: .main
        ) { _ in
            loadChatModes()
        }
    }

    private func loadChatModes() {
        Task {
            let loadedChatModes = await repository.getAllChatModes()
            DispatchQueue.main.async {
                let currentSelectionExists = loadedChatModes.contains { $0.id == self.selection?.id }
                self.chatModes = loadedChatModes
                if !currentSelectionExists {
                    self.selection = loadedChatModes.first
                }
            }
        }
    }

    private func addNewChatMode() {
        let newChatMode = ChatModeConfig(
            id: UUID().uuidString,
            name: "新模式",
            provider: nil,
            model: nil,
            rules: []
        )

        Task {
            let createdChatMode = await repository.createChatMode(config: newChatMode)
            DispatchQueue.main.async {
                self.chatModes.append(createdChatMode)
                self.selection = createdChatMode
            }
        }
    }
}

// 在ChatModeDetailView中添加
struct ChatModeDetailView: View {
    @State var chatMode: ChatModeConfig
    @Environment(\.chatModeConfigRepository) private var repository
    @Environment(\.llmProviderConfigRepository) private var providerRepository
    @Environment(\.ruleConfigRepository) private var ruleRepository
    @State private var providers: [LLMProviderConfig] = []
    @State private var allRules: [LLMRuleConfig] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 模型名称
                Text("模式名称")
                    .font(.title3)
                    .foregroundColor(.secondary)
                TextField("请输入模式名称", text: $chatMode.name)
                    .textFieldStyle(.plain)
                    .padding(10)
                    .background(Color(.controlBackgroundColor))
                    .cornerRadius(6)

                // 修改提供商选择部分
                Text("提供商")
                    .font(.title3)
                    .foregroundColor(.secondary)
                Picker("选择提供商", selection: $chatMode.provider) {
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
                    get: { chatMode.model?.modelName ?? "" },
                    set: {
                        if chatMode.model == nil {
                            chatMode.model = LLMModelConfig(
                                modelName: $0,
                                maxTokens: 2048,
                                temperature: 0.7,
                                topP: 1.0,
                                presencePenalty: 0.0,
                                frequencyPenalty: 0.0,
                                stopWords: []
                            )
                        } else {
                            chatMode.model?.modelName = $0
                        }
                    }
                ))
                .textFieldStyle(.plain)
                .padding(10)
                .background(Color(.controlBackgroundColor))
                .cornerRadius(6)

                // 规则列表
                Text("关联规则")
                    .font(.title3)
                    .foregroundColor(.secondary)
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(allRules, id: \.id) { rule in
                        HStack {
                            Toggle(isOn: Binding(
                                get: { chatMode.rules.contains(where: { $0.id == rule.id }) },
                                set: { isSelected in
                                    if isSelected {
                                        chatMode.rules.append(rule)
                                    } else {
                                        chatMode.rules.removeAll { $0.id == rule.id }
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
                            _ = await repository.updateChatMode(config: chatMode)
                        }
                    }
                    .controlSize(.large)
                    .buttonStyle(.borderedProminent)

                    Button("删除", role: .destructive) {
                        Task {
                            await repository.deleteChatMode(id: chatMode.id)
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

struct ChatModeSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ChatModeSettingsView()
                .environment(\.chatModeConfigRepository, MockChatModeConfigRepository())
                .environment(\.llmProviderConfigRepository, MockLLMProviderConfigRepository())
                .environment(\.ruleConfigRepository, MockRuleConfigRepository())

            //            ChatModeDetailView(
            //                chatMode: ChatModeConfig(
            //                    id: "preview-chatmode",
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
            //            .environment(\.chatModeConfigRepository, MockChatModeConfigRepository())
            //            .environment(\.llmProviderConfigRepository, MockLLMProviderConfigRepository())
            //            .environment(\.ruleConfigRepository, MockRuleConfigRepository())
            //            .previewDisplayName("聊天模式详情预览")
        }
    }
}

class MockChatModeConfigRepository: ChatModeConfigRepository {
    private var chatModes: [ChatModeConfig]

    init() {
        self.chatModes = []
    }

    func getAllChatModes() async -> [ChatModeConfig] {
        chatModes
    }

    func getChatMode(id: String) async -> ChatModeConfig? {
        chatModes.first { $0.id == id }
    }

    func createChatMode(config: ChatModeConfig) async -> ChatModeConfig {
        chatModes.append(config)
        return config
    }

    func updateChatMode(config: ChatModeConfig) async -> Bool {
        if let index = chatModes.firstIndex(where: { $0.id == config.id }) {
            chatModes[index] = config
        } else {
            chatModes.append(config)
        }
        return true
    }

    func deleteChatMode(id: String) async {
        chatModes.removeAll { $0.id == id }
    }
}
