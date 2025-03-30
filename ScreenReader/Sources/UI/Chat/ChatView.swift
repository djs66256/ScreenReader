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
    @Environment(\.llmProvider) var llmProvider
    @StateObject var viewModel: ChatViewModel
    @State var textInput = ""
    @FocusState private var isInputFocused: Bool
    @State private var displayedImages: [NSImage]
    
    // 添加状态来跟踪当前provider
    @State private var currentProvider: LLMProvider
    
    @MainActor
    init(viewModel: ChatViewModel? = nil, images: [NSImage] = []) {
        _viewModel = StateObject(wrappedValue: viewModel ?? ChatViewModel())
        _displayedImages = State(initialValue: images)
        _currentProvider = State(initialValue: LLMProviderFactory.defaultProvider)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(viewModel.messages, id: \.id) { message in
                            MessageView(message: message)
                                .transition(.opacity)
                                .id(message.id)
                        }
                    }
                    .padding(.vertical, 12)
                }
                .background(Color(.windowBackgroundColor))
                .overlay(
                    Divider()
                        .background(Color(.separatorColor))
                        .frame(maxWidth: .infinity),
                    alignment: .bottom
                )
            }
            
            HStack {
                VStack(spacing: 0) {
                    if !displayedImages.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(0..<displayedImages.count, id: \.self) { index in
                                    Image(nsImage: displayedImages[index])
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 60, height: 60)
                                        .cornerRadius(4)
                                        .overlay(
                                            Button(action: {
                                                // 实现删除图片逻辑
                                                displayedImages.remove(at: index)
                                            }) {
                                                Image(systemName: "xmark.circle.fill")
                                                    .font(.system(size: 16))
                                                    .foregroundColor(.white)
                                                    .background(Color.black.opacity(0.6))
                                                    .clipShape(Circle())
                                            }
                                            .buttonStyle(.plain)
                                            .padding(2),
                                            alignment: .topTrailing
                                        )
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.top, 8)
                        }
                    }
                    
                    // 输入区域
                    HStack(alignment: .bottom, spacing: 8) {
                        // 替换TextField为TextEditor
                        TextEditor(text: $textInput)
                            .frame(minHeight: 40, maxHeight: 120)
                            .padding(8)
                            .font(.system(size: 16)) // 设置字号为16
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(.controlBackgroundColor))
                                    .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color(.separatorColor).opacity(0.5), lineWidth: 1)
                            )
                            .focused($isInputFocused)
                            .scrollContentBackground(.hidden)
                            .onSubmit {
                                if !isShiftKeyPressed() {
                                    sendMessage()
                                }
                            }
                            .onChange(of: textInput) { _ in
                                DispatchQueue.main.async {
                                    if textInput.last == "\n" && !isShiftKeyPressed() {
                                        textInput.removeLast()
                                        sendMessage()
                                    }
                                }
                            }
                        
                        Button {
                            sendMessage() // 改为直接调用sendMessage方法
                        } label: {
                            Image(systemName: "paperplane.fill")
                                .padding(10)
                                .background(
                                    Circle()
                                        .fill(Color.accentColor)
                                        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                                )
                                .foregroundColor(.white)
                        }
                        .buttonStyle(.plain)
                        .keyboardShortcut(.return, modifiers: [])
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
                    .background(Color(.windowBackgroundColor))
                    .onAppear {
                        isInputFocused = true
                    }
                }
                .background(Color(.windowBackgroundColor))
                .background(
                    Divider()
                        .background(Color(.separatorColor))
                        .frame(height: 1),
                    alignment: .top
                )
            }
        }
        .environment(\.llmProvider, currentProvider)
        .onReceive(NotificationCenter.default.publisher(for: LLMManager.providerDidChange)) { _ in
            Task { @MainActor in
                if let providerID = LLMManager.shared.selectedProviderID,
                   let providerConfig = LLMManager.shared.provider(forID: providerID) {
//                    currentProvider = LLMProviderFactory.makeProvider(from: providerConfig)
                } else {
                    currentProvider = LLMProviderFactory.defaultProvider
                }
            }
        }
    }

    private func sendMessage() {
        guard !textInput.isEmpty || !displayedImages.isEmpty else { return }
        let currentText = textInput
        let currentImages = displayedImages // 保存当前图片
        textInput = ""
        displayedImages = [] // 立即清空图片列表
        Task { @MainActor in
            do {
                if currentImages.isEmpty {
                    try await viewModel.sendText(currentText, using: llmProvider)
                } else {
                    try await viewModel.sendMessage(text: currentText,
                                                   images: currentImages, // 使用保存的图片
                                                   using: llmProvider)
                }
                isInputFocused = true
            } catch {
                // do nothing
            }
        }
    }

    private func isShiftKeyPressed() -> Bool {
        #if os(macOS)
        return NSEvent.modifierFlags.contains(.shift)
        #else
        return false
        #endif
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
        
        return Group {
                ChatView(viewModel: viewModel)
                    .previewDisplayName("默认状态")
                
                ChatView(viewModel: viewModel, images: [redImage, blueImage, greenImage])
                    .previewDisplayName("带图片预览")
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

