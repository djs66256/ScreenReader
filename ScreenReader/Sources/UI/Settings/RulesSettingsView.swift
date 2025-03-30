import SwiftUI

// 在文件顶部添加环境对象定义
struct LLMRuleConfigRepositoryKey: EnvironmentKey {
    static let defaultValue: any LLMRuleConfigRepository = MockRuleConfigRepository()
}

extension EnvironmentValues {
    var ruleConfigRepository: any LLMRuleConfigRepository {
        get { self[LLMRuleConfigRepositoryKey.self] }
        set { self[LLMRuleConfigRepositoryKey.self] = newValue }
    }
}

struct RulesSettingsView: View {
    @Environment(\.ruleConfigRepository) private var repository
    @State private var newRuleName = ""
    @State private var rules: [LLMRuleConfig] = []
    @State private var refreshID = UUID()
    @State private var observer: Any?
    @State private var selection: LLMRuleConfig? // 添加选择状态
    
    var body: some View {
        SidebarSettingsView(
            items: $rules,
            selection: $selection, // 传递选择绑定
            leftContent: { rule in
                HStack {
                    Image(systemName: "text.bubble")
                    Text(rule.name)
                }
            },
            rightContent: { rule in
                RuleDetailView(rule: rule)
            },
            bottomContent: {
                Button(action: addNewRule) {
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
            loadRules()
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
            forName: .llmRuleConfigChanged,
            object: nil,
            queue: .main
        ) { _ in
            loadRules()
        }
    }
    
    private func loadRules() {
        Task {
            let loadedRules = await repository.getAllRules()
            DispatchQueue.main.async {
                let currentSelectionExists = loadedRules.contains { $0.id == self.selection?.id }
                self.rules = loadedRules
                if !currentSelectionExists {
                    self.selection = loadedRules.first
                }
            }
        }
    }
    
    private func addNewRule() {
        let newRule = LLMRuleConfig(
            id: UUID().uuidString,
            name: "新规则", 
            systemPrompt: nil
        )
        
        Task {
            // 直接通过repository创建规则
            let createdRule = await repository.createRule(rule: newRule)
            DispatchQueue.main.async {
                self.rules.append(createdRule)
                self.selection = createdRule
            }
        }
    }
}

struct RuleDetailView: View {
    @State var rule: LLMRuleConfig
    @Environment(\.ruleConfigRepository) private var repository
    @State private var showHelpTip = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 规则名称输入框
                Text("规则名称")
                    .font(.title3)
                    .foregroundColor(.secondary)
                TextField("请输入规则名称", text: $rule.name)
                    .textFieldStyle(.plain)
                    .padding(10)
                    .background(Color(.controlBackgroundColor))
                    .cornerRadius(6)
                
                // 系统提示词输入框
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("系统提示词")
                                .font(.title3)
                                .foregroundColor(.secondary)
                            
                            Button(action: { showHelpTip.toggle() }) {
                                Image(systemName: "questionmark.circle")
                                    .foregroundColor(.blue)
                            }
                            .buttonStyle(.plain)
                            .popover(isPresented: $showHelpTip) {
                                Text("该内容将会插入系统提示词中")
                                    .padding()
                                    .frame(width: 200)
                            }
                        }
                        
                        TextEditor(text: Binding(
                            get: { rule.systemPrompt ?? "" },
                            set: { rule.systemPrompt = $0.isEmpty ? nil : $0 }
                        ))
                        .frame(minHeight: 120)
                        .padding(10)
                        .background(Color(.controlBackgroundColor))
                        .cornerRadius(6)
                    }
                }
                
                HStack {
                    Button("保存") {
                        Task {
                            _ = await repository.updateRule(rule: rule)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button("删除", role: .destructive) {
                        Task {
                            await repository.deleteRule(id: rule.id)
                        }
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
        }
    }
}

// 修改预览部分
struct RulesSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            RulesSettingsView()
                .environment(\.ruleConfigRepository, MockRuleConfigRepository())
            
            RuleDetailView(
                rule: LLMRuleConfig(
                    id: "preview-rule",
                    name: "预览规则",
                    systemPrompt: "这是一个系统提示词的示例"
                )
            )
            .environment(\.ruleConfigRepository, MockRuleConfigRepository())
            .previewDisplayName("规则详情预览")
        }
    }
}

class MockRuleConfigRepository: LLMRuleConfigRepository {
    private var rules: [LLMRuleConfig]
    
    init() {
        // 添加2条默认规则
        self.rules = [
            LLMRuleConfig(
                id: "default-rule-1",
                name: "默认规则1",
                systemPrompt: "这是第一条默认规则的系统提示词"
            ),
            LLMRuleConfig(
                id: "default-rule-2", 
                name: "默认规则2",
                systemPrompt: "这是第二条默认规则的系统提示词"
            )
        ]
    }
    
    func getRule(id: String) async -> LLMRuleConfig? {
        rules.first { $0.id == id }
    }

    func createRule(rule: LLMRuleConfig) async -> LLMRuleConfig {
        rules.append(rule)
        return rule
    }

    func deleteRule(id: String) async {
        rules.removeAll { $0.id == id }
    }

    func getAllRules() async -> [LLMRuleConfig] {
        rules
    }
    
    func createRule(rule: LLMRuleConfig) async -> Bool {
        rules.append(rule)
        return true
    }
    
    func updateRule(rule: LLMRuleConfig) async -> Bool {
        if let index = rules.firstIndex(where: { $0.id == rule.id }) {
            rules[index] = rule
        } else {
            rules.append(rule)
        }
        return true
    }
    
    func deleteRule(id: String) async -> Bool {
        rules.removeAll { $0.id == id }
        return true
    }
}
