import SwiftUI

struct LLMProviderConfigRepositoryKey: EnvironmentKey {
    static let defaultValue: any LLMProviderConfigRepository = MockLLMProviderConfigRepository()
}

extension EnvironmentValues {
    var llmProviderConfigRepository: any LLMProviderConfigRepository {
        get { self[LLMProviderConfigRepositoryKey.self] }
        set { self[LLMProviderConfigRepositoryKey.self] = newValue }
    }
}

struct APIProviderSettingsView: View {
    @Environment(\.llmProviderConfigRepository) private var repository
    @State private var providers: [LLMProviderConfig] = []
    @State private var selection: LLMProviderConfig?
    @State private var observer: Any?
    
    var body: some View {
        SidebarSettingsView(
            items: $providers,
            selection: $selection,
            leftContent: { provider in
                HStack {
                    Image(systemName: "server.rack")
                    Text(provider.name)
                }
            },
            rightContent: { provider in
                ProviderDetailView(provider: provider)
            },
            bottomContent: {
                Button(action: addNewProvider) {
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
            loadProviders()
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
            forName: .llmProviderConfigChanged,
            object: nil,
            queue: .main
        ) { _ in
            loadProviders()
        }
    }
    
    private func loadProviders() {
        Task {
            let loadedProviders = await repository.getAllConfigs()
            DispatchQueue.main.async {
                let currentSelectionExists = loadedProviders.contains { $0.id == self.selection?.id }
                self.providers = loadedProviders
                if !currentSelectionExists {
                    self.selection = loadedProviders.first
                }
            }
        }
    }
    
    private func addNewProvider() {
        let newProvider = LLMProviderConfig(
            id: UUID().uuidString,
            name: "新提供商",
            defaultBaseURL: nil,
            apiKey: nil,
            supportedModelIDs: []
        )
        
        Task {
            let createdProvider = await repository.createConfig(config: newProvider)
            DispatchQueue.main.async {
                self.providers.append(createdProvider)
                self.selection = createdProvider
            }
        }
    }
}

struct ProviderDetailView: View {
    @State var provider: LLMProviderConfig
    @Environment(\.llmProviderConfigRepository) private var repository
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 提供商名称
                Text("提供商名称")
                    .font(.title3)
                    .foregroundColor(.secondary)
                TextField("请输入提供商名称", text: $provider.name)
                    .textFieldStyle(.plain)
                    .padding(10)
                    .background(Color(.controlBackgroundColor))
                    .cornerRadius(6)
                
                // API基础URL
                Text("API基础URL")
                    .font(.title3)
                    .foregroundColor(.secondary)
                TextField("https://api.example.com", text: Binding(
                    get: { provider.defaultBaseURL ?? "" },
                    set: { provider.defaultBaseURL = $0.isEmpty ? nil : $0 }
                ))
                .textFieldStyle(.plain)
                .padding(10)
                .background(Color(.controlBackgroundColor))
                .cornerRadius(6)
                
                // API密钥
                Text("API密钥")
                    .font(.title3)
                    .foregroundColor(.secondary)
                SecureField("输入API密钥", text: Binding(
                    get: { provider.apiKey ?? "" },
                    set: { provider.apiKey = $0.isEmpty ? nil : $0 }
                ))
                .textFieldStyle(.plain)
                .padding(10)
                .background(Color(.controlBackgroundColor))
                .cornerRadius(6)
                
                HStack {
                    Button("保存") {
                        Task {
                            _ = await repository.updateConfig(config: provider)
                        }
                    }
                    .controlSize(.large)
                    .buttonStyle(.borderedProminent)
                    
                    Button("删除", role: .destructive) {
                        Task {
                            await repository.deleteConfig(id: provider.id)
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

struct APIProviderSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            APIProviderSettingsView()
                .environment(\.llmProviderConfigRepository, MockLLMProviderConfigRepository())
            
            ProviderDetailView(
                provider: LLMProviderConfig(
                    id: "preview-provider",
                    name: "预览提供商",
                    defaultBaseURL: "https://api.example.com",
                    apiKey: "sk-1234567890",
                    supportedModelIDs: ["gpt-4", "gpt-3.5-turbo"]
                )
            )
            .environment(\.llmProviderConfigRepository, MockLLMProviderConfigRepository())
            .previewDisplayName("提供商详情预览")
        }
    }
}

class MockLLMProviderConfigRepository: LLMProviderConfigRepository {
    private var providers: [LLMProviderConfig]
    
    init() {
        self.providers = [
            LLMProviderConfig(
                id: "default-provider-1",
                name: "OpenAI",
                defaultBaseURL: "https://api.openai.com",
                apiKey: nil,
                supportedModelIDs: ["gpt-4", "gpt-3.5-turbo"]
            ),
            LLMProviderConfig(
                id: "default-provider-2",
                name: "Anthropic",
                defaultBaseURL: "https://api.anthropic.com",
                apiKey: nil,
                supportedModelIDs: ["claude-2", "claude-instant"]
            )
        ]
    }
    
    func getAllConfigs() async -> [LLMProviderConfig] {
        providers
    }
    
    func getConfig(id: String) async -> LLMProviderConfig? {
        providers.first { $0.id == id }
    }
    
    func createConfig(config: LLMProviderConfig) async -> LLMProviderConfig {
        providers.append(config)
        return config
    }
    
    func updateConfig(config: LLMProviderConfig) async -> Bool {
        if let index = providers.firstIndex(where: { $0.id == config.id }) {
            providers[index] = config
        } else {
            providers.append(config)
        }
        return true
    }
    
    func deleteConfig(id: String) async {
        providers.removeAll { $0.id == id }
    }
}
