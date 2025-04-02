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
    @State private var showTypeSelection: Bool = false
    
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
        .sheet(isPresented: $showTypeSelection) {
            TypeSelectionView(
                onSelect: { template in
                    createProvider(from: template)
                    showTypeSelection = false
                },
                onCancel: { showTypeSelection = false }
            )
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
        showTypeSelection = true
    }
    
    private func createProvider(from template: LLMProviderConfig) {
        Task {
            var templateCopy = template
            templateCopy.id = UUID().uuidString
            let createdProvider = await repository.createConfig(config: templateCopy)
            DispatchQueue.main.async {
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
                // 提供商类型 (不可编辑样式)
                Text("提供商类型")
                    .font(.title3)
                    .foregroundColor(.secondary)
                HStack {
                    Text(provider.type)
                        .foregroundColor(.secondary)
                    Spacer()
                    Image(systemName: "lock.fill")
                        .foregroundColor(.gray)
                }
                .padding(10)
                .background(Color(.controlBackgroundColor).opacity(0.5))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
                
                // 提供商名称 (可编辑字段)
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

struct TypeSelectionView: View {
    @Environment(\.llmProviderConfigRepository) private var repository
    @State private var templates: [LLMProviderConfig] = []
    let onSelect: (LLMProviderConfig) -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            Text("选择提供商类型")
                .font(.headline)
                .padding(.top, 20)
                .padding(.bottom, 10)
            
            Divider()
            
            List {
                ForEach(templates, id: \.id) { template in
                    Button(action: { onSelect(template) }) {
                        HStack {
                            Image(systemName: "server.rack")
                                .foregroundColor(.primary)  // 修改为与外部一致的颜色
                            Text(template.name)
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .listStyle(.plain)
            
            Divider()
            
            Button("取消", action: onCancel)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color(.controlBackgroundColor))
        }
        .frame(width: 300, height: 400)
        .onAppear {
            loadTemplates()
        }
    }
    
    private func loadTemplates() {
        Task {
            let loadedTemplates = await repository.getAllTemplates()
            DispatchQueue.main.async {
                self.templates = loadedTemplates
            }
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
                    type: "openai",
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
    func getAllTemplates() async -> [LLMProviderConfig] {
        return [
            LLMProviderConfig(
                id: "template-openai",
                type: "openai",
                name: "OpenAI",
                defaultBaseURL: "https://api.openai.com",
                apiKey: nil,
                supportedModelIDs: ["gpt-4", "gpt-3.5-turbo"]
            ),
            LLMProviderConfig(
                id: "template-anthropic",
                type: "anthropic",
                name: "Anthropic",
                defaultBaseURL: "https://api.anthropic.com",
                apiKey: nil,
                supportedModelIDs: ["claude-2", "claude-instant"]
            )
        ]
    }

    private var providers: [LLMProviderConfig]
    
    init() {
        self.providers = [
            LLMProviderConfig(
                id: "default-provider-1",
                type: "openai",
                name: "OpenAI",
                defaultBaseURL: "https://api.openai.com",
                apiKey: nil,
                supportedModelIDs: ["gpt-4", "gpt-3.5-turbo"]
            ),
            LLMProviderConfig(
                id: "default-provider-2",
                type: "anthropic",
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

