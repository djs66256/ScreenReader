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
            VStack(alignment: .leading, spacing: 16) {  // 调整间距为16
                // 标题样式
                Text("API 设置")
                    .font(.title3)  // 改为更小的标题
                    .bold()
                    .foregroundColor(.primary)  // 使用系统主色
                    .padding(.bottom, 8)
                
                // Provider选择器
                settingsSection(title: "API 提供商") {
                    Picker("选择提供商", selection: $selectedProvider) {
                        ForEach(llmManager.allProviders, id: \.id) { provider in
                            Text(provider.name).tag(provider.id as String?)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(.accentColor)  // 使用系统强调色
                }
                
                // 输入框组
                settingsSection(title: "连接设置") {
                    VStack(spacing: 12) {
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
                        .padding(.vertical, 8)
                        .background(Color.accentColor)  // 使用系统强调色
                        .foregroundColor(.white)
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .padding(.top, 16)
            }
            .padding()
        }
        .frame(minWidth: 400, idealWidth: 450, maxWidth: 500)  // 设置合适的窗口大小
        .onAppear {
            loadSettings()
        }
    }
    
    // 辅助视图 - 设置区块
    @ViewBuilder
    private func settingsSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
                .foregroundColor(.secondary)  // 使用系统次要色
            
            content()
                .padding()
                .background(Color(.controlBackgroundColor))  // 使用系统控件背景色
                .cornerRadius(6)
        }
    }
    
    // 辅助视图 - 文本输入框
    private func settingsTextField(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .textFieldStyle(.roundedBorder)  // 使用圆角边框样式
    }
    
    // 辅助视图 - 安全输入框
    private func settingsSecureField(_ placeholder: String, text: Binding<String>) -> some View {
        SecureField(placeholder, text: text)
            .textFieldStyle(.roundedBorder)  // 使用圆角边框样式
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
        Group {
            // 亮色模式预览
            SettingsView()
                .preferredColorScheme(.light)
                .previewDisplayName("亮色模式")
            
            // 暗色模式预览
            SettingsView()
                .preferredColorScheme(.dark)
                .previewDisplayName("暗色模式")
            
            // 辅助功能大字体预览
            SettingsView()
                .environment(\.sizeCategory, .accessibilityLarge)
                .previewDisplayName("大字体")
        }
        .frame(width: 500)  // 统一预览宽度
    }
}
