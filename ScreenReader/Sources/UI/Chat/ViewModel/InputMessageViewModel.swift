import Foundation
import AppKit
import Combine

class InputMessageViewModel: ObservableObject {
    @Published var textInput: String = ""
    @Published var displayedImages: [NSImage] = []
    @Published var isInputFocused: Bool = true
    @Published var selectedModel: AgentConfig?
    @Published var agents: [AgentConfig] = []
    
    private let repository: AgentConfigRepository
    private var cancellables = Set<AnyCancellable>()
    
    init(repository: AgentConfigRepository = LLMConfigManager.shared.agentConfigRepository) {
        self.repository = repository
        fetchAgents()
        
        // 使用 publisher 监听配置变更
        NotificationCenter.default.publisher(for: .agentConfigChanged)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.fetchAgents()
            }
            .store(in: &cancellables)
    }
    
    func clearInput() {
        textInput = ""
        displayedImages = []
    }
    
    func addImage(_ image: NSImage) {
        displayedImages.append(image)
    }
    
    func removeImage(at index: Int) {
        guard displayedImages.indices.contains(index) else { return }
        displayedImages.remove(at: index)
    }
    
    func updateSelectedModel(_ model: AgentConfig?) {
        selectedModel = model
    }
    
    private func fetchAgents() {
        Task {
            let agents = await repository.getAllAgents()
            DispatchQueue.main.async {
                self.agents = agents
                
                // 如果当前选中的模型不在更新后的列表中，则选择第一个
                if let selected = self.selectedModel {
                    if !agents.contains(where: { $0.id == selected.id }) {
                        self.selectedModel = agents.first
                    } else if let updatedModel = agents.first(where: { $0.id == selected.id }) {
                        // 更新当前选中的模型为最新版本
                        self.selectedModel = updatedModel
                    }
                } else {
                    self.selectedModel = agents.first
                }
            }
        }
    }
}

extension InputMessageViewModel {
    static func mock() -> InputMessageViewModel {
        let repository = MockAgentConfigRepository()
        let viewModel = InputMessageViewModel(repository: repository)
        viewModel.textInput = "这是一个测试消息"
        viewModel.isInputFocused = true
        
        // 添加测试图片
        let redImage = NSImage(size: NSSize(width: 100, height: 100))
        redImage.lockFocus()
        NSColor.systemRed.drawSwatch(in: NSRect(origin: .zero, size: redImage.size))
        redImage.unlockFocus()
        
        let blueImage = NSImage(size: NSSize(width: 100, height: 100))
        blueImage.lockFocus()
        NSColor.systemBlue.drawSwatch(in: NSRect(origin: .zero, size: blueImage.size))
        blueImage.unlockFocus()
        
        viewModel.displayedImages = [redImage, blueImage]
        
        // 直接设置测试模型，因为 mock repository 不会返回数据
        viewModel.agents = [
            AgentConfig(id: "mode1", name: "模式1", rules: []),
            AgentConfig(id: "mode2", name: "模式2", rules: []),
            AgentConfig(id: "mode3", name: "模式3", rules: [])
        ]
        viewModel.selectedModel = viewModel.agents.first
        
        return viewModel
    }
}
