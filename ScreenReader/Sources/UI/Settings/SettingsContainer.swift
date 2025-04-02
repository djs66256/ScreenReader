import SwiftUI

struct SettingsContainer: View {
    enum SettingsTab: String, CaseIterable {
        case agent = "Agent模式"
        case apiProvider = "API提供商"
        case rules = "规则设置"
    }
    
    @State private var selectedTab: SettingsTab = .agent
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部标签栏
            HStack(spacing: 0) {
                ForEach(SettingsTab.allCases, id: \.self) { tab in
                    Button(action: {
                        selectedTab = tab
                    }) {
                        Text(tab.rawValue)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(selectedTab == tab ? Color.accentColor.opacity(0.2) : Color.white.opacity(0.001)) // 使用极低透明度的白色替代clear
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
            
            Divider()
            
            // 内容区域
            Group {
                switch selectedTab {
                case .agent:
                    AgentSettingsView()
                case .apiProvider:
                    APIProviderSettingsView()  // 重用原有的API设置视图
                case .rules:
                    RulesSettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 800, minHeight: 600)
        .environment(\.ruleConfigRepository, LLMConfigManager.shared.ruleConfigRepository)
        .environment(\.llmProviderConfigRepository, LLMConfigManager.shared.providerConfigRepository)
        .environment(\.agentConfigRepository, LLMConfigManager.shared.agentConfigRepository)
    }
}

// 预览
struct SettingsContainer_Previews: PreviewProvider {
    static var previews: some View {
        SettingsContainer()
        .environment(\.ruleConfigRepository, MockRuleConfigRepository())
    }
}
