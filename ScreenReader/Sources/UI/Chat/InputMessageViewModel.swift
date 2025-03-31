import Foundation
import AppKit
import Combine

class InputMessageViewModel: ObservableObject {
    @Published var textInput: String = ""
    @Published var displayedImages: [NSImage] = []
    @Published var isInputFocused: Bool = true
    @Published var selectedModel: ChatModeConfig?
    @Published var chatModes: [ChatModeConfig] = []
    
    private let repository: ChatModeConfigRepository
    private var cancellables = Set<AnyCancellable>()
    
    init(repository: ChatModeConfigRepository = LLMConfigManager.shared.chatModeConfigRepository) {
        self.repository = repository
        fetchChatModes()
        
        // 使用 publisher 监听配置变更
        NotificationCenter.default.publisher(for: .chatModeConfigChanged)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.fetchChatModes()
            }
            .store(in: &cancellables)
    }
    
    deinit {
        // 移除通知观察者
        if let observer = configObserver {
            NotificationCenter.default.removeObserver(observer)
        }
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
    
    func updateSelectedModel(_ model: ChatModeConfig?) {
        selectedModel = model
    }
    
    private func fetchChatModes() {
        Task {
            let modes = await repository.getAllChatModes()
            DispatchQueue.main.async {
                self.chatModes = modes
                
                // 如果当前选中的模型不在更新后的列表中，则选择第一个
                if let selected = self.selectedModel {
                    if !modes.contains(where: { $0.id == selected.id }) {
                        self.selectedModel = modes.first
                    } else if let updatedModel = modes.first(where: { $0.id == selected.id }) {
                        // 更新当前选中的模型为最新版本
                        self.selectedModel = updatedModel
                    }
                } else {
                    self.selectedModel = modes.first
                }
            }
        }
    }
}

extension InputMessageViewModel {
    static func mock() -> InputMessageViewModel {
        let repository = MockChatModeConfigRepository()
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
        viewModel.chatModes = [
            ChatModeConfig(id: "mode1", name: "模式1", rules: []),
            ChatModeConfig(id: "mode2", name: "模式2", rules: []),
            ChatModeConfig(id: "mode3", name: "模式3", rules: [])
        ]
        viewModel.selectedModel = viewModel.chatModes.first
        
        return viewModel
    }
}