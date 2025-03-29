import SwiftUI
import MarkdownUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// 在文件顶部添加环境变量定义
struct SelectedImagesKey: EnvironmentKey {
    static let defaultValue: [NSImage] = []
}

extension EnvironmentValues {
    var selectedImages: [NSImage] {
        get { self[SelectedImagesKey.self] }
        set { self[SelectedImagesKey.self] = newValue }
    }
}

// 修改ChatView结构体，添加环境变量声明
struct ChatView: View {
    @Environment(\.selectedImages) var selectedImages
    @StateObject var viewModel = ChatViewModel()
    @State var textInput = ""
    @FocusState private var isInputFocused: Bool  // 添加焦点状态
    
    private func scrollToBottom(proxy: ScrollViewProxy) {
        guard let last = viewModel.messages.last else { return }
        withAnimation {
            proxy.scrollTo(last.id, anchor: .bottom)
        }
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
                    // 图片预览区域 - 现在放在输入框上方
                    if !selectedImages.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(0..<selectedImages.count, id: \.self) { index in
                                    Image(nsImage: selectedImages[index])
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 60, height: 60)  // 修改为60x60
                                        .cornerRadius(4)
                                        .overlay(
                                            Button(action: {
                                                // 移除图片逻辑
                                            }) {
                                                Image(systemName: "xmark.circle.fill")
                                                    .font(.system(size: 16))  // 相应缩小关闭按钮
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
                        TextField("输入消息...", text: $textInput, axis: .vertical)
                            .textFieldStyle(.plain)
                            .padding(10)
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
                            .contentShape(Rectangle())
                        
                        Button {
                            viewModel.sendText(textInput)
                            textInput = ""
                            isInputFocused = true
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
    }
}

// 添加预览代码
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
                
                ChatView(viewModel: viewModel)
                    .preferredColorScheme(.dark)
                    .previewDisplayName("深色模式")
            
                ChatView(viewModel: viewModel)
                    .previewDisplayName("图片预览-亮色")
                    .environment(\.selectedImages, [redImage, blueImage, greenImage])
                
                ChatView(viewModel: viewModel)
                    .preferredColorScheme(.dark)
                    .previewDisplayName("图片预览-暗色")
                    .environment(\.selectedImages, [redImage, blueImage, greenImage])
        }
        .frame(width: 500, height: 800) // 设置预览窗口大小
    }
}
