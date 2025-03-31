import SwiftUI
import MarkdownUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// 在文件顶部添加环境变量定义
struct LLMProviderKey: EnvironmentKey {
    static let defaultValue: LLMProvider = LLMProviderFactory.defaultProvider
}

extension EnvironmentValues {
    var llmProvider: LLMProvider {
        get { self[LLMProviderKey.self] }
        set { self[LLMProviderKey.self] = newValue }
    }
}

// 移除 SelectedImagesKey 和环境变量扩展
struct ChatView: View {
    @StateObject var chatViewModel: ChatViewModel
    @StateObject var inputViewModel: InputMessageViewModel
    
    init(viewModel: ChatViewModel? = nil, inputViewModel: InputMessageViewModel = InputMessageViewModel()) {
        _chatViewModel = StateObject(wrappedValue: viewModel ?? ChatViewModel())
        _inputViewModel = StateObject(wrappedValue: inputViewModel)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(chatViewModel.messages, id: \.id) { message in
                            MessageView(message: message)
                                .transition(.opacity)
                                .id(message.id)
                        }
                    }
                    .padding(.vertical, 12)
                }
                .background(Color(.windowBackgroundColor))
            }
            
            Divider()
                .background(Color(.separatorColor))
            
            InputArea(viewModel: inputViewModel, sendMessage: sendMessage)
            
            BottomToolbar(viewModel: inputViewModel, sendMessage: sendMessage)
        }
    }

    private func sendMessage() {
        guard !inputViewModel.textInput.isEmpty || !inputViewModel.displayedImages.isEmpty else { return }
        
        let currentText = inputViewModel.textInput
        let currentImages = inputViewModel.displayedImages
        inputViewModel.clearInput()
    }
}

// 修改预览代码
struct ChatView_Previews: PreviewProvider {
    // 创建纯色图片
    static func solidColorImage(color: NSColor, size: NSSize = NSSize(width: 200, height: 200)) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        color.drawSwatch(in: NSRect(origin: .zero, size: size))
        image.unlockFocus()
        return image
    }
    
    static var previews: some View {
        // 创建几种纯色图片
        let redImage = solidColorImage(color: .systemRed)
        let blueImage = solidColorImage(color: .systemBlue)
        let greenImage = solidColorImage(color: .systemGreen)
        
        let mockMessages = [
            ChatMessage(
                contents: [ChatContent.text("你好！`开始`**还是**")],
                isUser: true
            ),
            ChatMessage(
                contents: [ChatContent.text("您好，有什么可以帮您？")],
                isUser: false
            ),
            ChatMessage(
                contents: [ChatContent.imageData(redImage.tiffRepresentation!), ChatContent.text("这是红色图片")],
                isUser: true
            ),
            ChatMessage(
                contents: [ChatContent.imageData(blueImage.tiffRepresentation!)],
                isUser: true
            ),
            ChatMessage(
                contents: [ChatContent.text("这是蓝色图片")],
                isUser: false
            ),
            ChatMessage(
                contents: [ChatContent.imageData(greenImage.tiffRepresentation!)],
                isUser: true
            ),
            ChatMessage(
                contents: [ChatContent.thinking("正在思考...")],
                isUser: false,
                isProcessing: true
            )
        ]
        
        let viewModel = ChatViewModel()
        viewModel.messages = mockMessages
        
        // 创建模拟的输入视图模型
        let mockInputViewModel = InputMessageViewModel.mock()
        
        return Group {
            ChatView(viewModel: viewModel)
                .previewDisplayName("默认状态")
            
            ChatView(viewModel: viewModel, inputViewModel: mockInputViewModel)
                .previewDisplayName("带模拟输入的状态")
            
        }.frame(maxWidth: 400)
    }
}

extension NSAlert {
    static func showToast(message: String, duration: TimeInterval = 3.0) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = message
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            
            // Show the alert without making it modal
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 300, height: 100),
                                styleMask: [.titled],
                                backing: .buffered,
                                defer: false)
            window.center()
            window.isReleasedWhenClosed = false
            alert.beginSheetModal(for: window) { _ in
                window.close()
            }
            
            // Auto-dismiss after duration
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                window.close()
            }
        }
    }
}

