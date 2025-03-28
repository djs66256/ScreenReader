import SwiftUI

struct SettingsView: View {
    var llmManager = LLMManager.shared // 引入 LLMManager
    @State private var selectedProvider: String? {
        didSet {
            updateFieldsForSelectedProvider()
        }
    }
    @State private var baseURL = ""
    @State private var apiKey = ""
    @State private var modelName = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 标题样式
                Text("API 设置")
                    .font(.title2)
                    .bold()
                    .foregroundColor(.white)
                    .padding(.bottom, 10)
                
                // Provider选择器
                settingsSection(title: "API 提供商") {
                    Picker("选择提供商", selection: $selectedProvider) {
                        ForEach(llmManager.allProviders, id: \.id) { provider in
                            Text(provider.name).tag(provider.id as String?)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(.white)
                    .onChange(of: selectedProvider) { _, _ in
                        updateFieldsForSelectedProvider()
                    }
                }
                
                // 输入框组
                settingsSection(title: "连接设置") {
                    VStack(spacing: 15) {
                        settingsTextField("基础URL", text: $baseURL)
                        settingsSecureField("API密钥", text: $apiKey)
                        settingsTextField("模型名称", text: $modelName)
                    }
                }
                
                // 保存按钮
                Button(action: saveSettings) {
                    Text("保存设置")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue.opacity(0.8))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .shadow(color: .blue.opacity(0.3), radius: 5, x: 0, y: 2)
                }
                .buttonStyle(.plain)
                .padding(.top, 20)
            }
            .padding()
        }
        .onAppear {
            loadSettings()
        }
    }
    
    // 辅助视图 - 设置区块
    @ViewBuilder
    private func settingsSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(.white.opacity(0.8))
                .padding(.leading, 5)
            
            content()
                .padding()
                .background(Color.white.opacity(0.1))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        }
    }
    
    // 辅助视图 - 文本输入框
    private func settingsTextField(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .textFieldStyle(.plain)
            .padding()
            .background(Color.white.opacity(0.05))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
            .foregroundColor(.white)
            .accentColor(.blue)
    }
    
    // 辅助视图 - 安全输入框
    private func settingsSecureField(_ placeholder: String, text: Binding<String>) -> some View {
        SecureField(placeholder, text: text)
            .textFieldStyle(.plain)
            .padding()
            .background(Color.white.opacity(0.05))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
            .foregroundColor(.white)
    }

    private func loadSettings() {
        // 优先使用LLMManager中保存的selectedProviderID
        if let savedProviderID = llmManager.selectedProviderID {
            selectedProvider = savedProviderID
        } else {
            // 如果没有保存的选择，使用第一个provider
            selectedProvider = llmManager.allProviders.first?.id
        }
    }

    private func saveSettings() {
        guard let selectedProviderId = selectedProvider,
              let provider = llmManager.provider(forID: selectedProviderId) else {
            return
        }
        
        let updatedProvider = LLMProviderConfig(
            id: provider.id,
            name: provider.name,
            apiKey: apiKey.isEmpty ? nil : apiKey,
            defaultBaseURL: baseURL.isEmpty ? nil : baseURL,
            supportedModelIDs: [modelName]
        )
        
        // 更新provider到manager并保存
        llmManager.updateProvider(updatedProvider)
        llmManager.setSelectedProvider(selectedProviderId)
    }
    
    private func updateFieldsForSelectedProvider() {
        guard let selectedProviderId = selectedProvider,
              let provider = llmManager.provider(forID: selectedProviderId) else {
            baseURL = ""
            apiKey = ""
            modelName = ""
            return
        }
        
        baseURL = provider.defaultBaseURL ?? ""
        apiKey = provider.apiKey ?? ""
        modelName = provider.supportedModelIDs.first ?? ""
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .preferredColorScheme(.dark) // 设置为暗色模式以匹配截图中的样式
    }
}
