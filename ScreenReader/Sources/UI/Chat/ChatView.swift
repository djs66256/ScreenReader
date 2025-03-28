import SwiftUI
import MarkdownUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct ChatView: View {
    @StateObject var viewModel = ChatViewModel()
    @State var textInput = ""
    
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
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.messages, id: \.id) { message in
                            MessageView(message: message)
                                .transition(.opacity.combined(with: .scale(scale: 0.9)))
                                .id(message.id)
                        }
                    }
                    .padding(.vertical, 16)
                }
                .background(Color(nsColor: .windowBackgroundColor))  // 修改为macOS专用颜色
                .onChange(of: viewModel.messages) { _ in
                    scrollToBottom(proxy: proxy)
                }
            }
            
            HStack {
                TextField("输入消息...", text: $textInput)
                    .textFieldStyle(.roundedBorder)
                    .padding(.vertical, 8)
                
                Button {
                    viewModel.sendText(textInput)
                    textInput = ""
                } label: {
                    Image(systemName: "paperplane.fill")
                        .padding(10)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
            .background(Color(nsColor: .controlBackgroundColor))  // 修改为macOS专用颜色
        }
    }
}

struct MessageView: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.isUser {
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(message.contents) { content in
                    switch content.type {
                    case .text:
                        Markdown(content.value)
                            .markdownTheme(.gitHub)
                            .textSelection(.enabled)
                            .markdownTextStyle {
                                BackgroundColor(.clear)
                                ForegroundColor(.clear)
                            }
                    case .imageURL:
                        AsyncImage(url: URL(string: content.value)) { image in
                            image.resizable().scaledToFit()
                        } placeholder: {
                            ProgressView()
                        }
                    case .imageData:
                        // 处理base64图片数据
                        if let data = content.imageData {
                            #if canImport(UIKit)
                            if let uiImage = UIImage(data: data) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFit()
                            }
                            #elseif canImport(AppKit)
                            if let nsImage = NSImage(data: data) {
                                Image(nsImage: nsImage)
                                    .resizable()
                                    .scaledToFit()
                            }
                            #endif
                        }
                    case .thinking:
                        Markdown("_\(content.value)_")
                            .markdownTheme(.gitHub)
                    }
                }
            }
            .padding(12)
            .background(
                Group {
                    if message.isUser {
                        LinearGradient(gradient: Gradient(colors: [
                            Color(red: 0.2, green: 0.5, blue: 1.0),
                            Color(red: 0.1, green: 0.4, blue: 0.9)
                        ]), startPoint: .topLeading, endPoint: .bottomTrailing)
                    } else {
                        Color(nsColor: .controlBackgroundColor).opacity(0.9)
                    }
                }
            )
            .foregroundColor(message.isUser ? .white : .primary)
            .cornerRadius(18)
            .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
            
            if !message.isUser {
                Spacer()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }
}

// 添加预览代码
struct ChatView_Previews: PreviewProvider {
    static var previews: some View {
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
                contents: [ChatContent.imageURL(URL(string: "https://example.com/image.jpg")!)],
                isUser: true
            ),
            ChatMessage(
                contents: [ChatContent.text("你好！`开始`**还是**")],
                isUser: true
            ),
            ChatMessage(
                contents: [ChatContent.text("您好，有什么可以帮您？")],
                isUser: false
            ),
            ChatMessage(
                contents: [ChatContent.imageURL(URL(string: "https://example.com/image.jpg")!)],
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
                .previewDisplayName("正常模式")
            
            ChatView(viewModel: viewModel)
                .preferredColorScheme(.dark)
                .previewDisplayName("深色模式")
            
            ChatView(viewModel: viewModel)
                .previewDevice("iPhone SE (3rd generation)")
                .previewDisplayName("小屏设备")
        }
    }
}
