import SwiftUI
import MarkdownUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct MessageView: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.isUser {
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 6) {
                ForEach(message.contents) { content in
                    switch content.type {
                    case .text:
                        Markdown(content.value)
                            .markdownTheme(.gitHub)
                            .textSelection(.enabled)
                            .markdownTextStyle {
                                ForegroundColor(message.isUser ? .white : .primary)
                                BackgroundColor(.clear)
                            }
                    case .imageURL:
                        AsyncImage(url: URL(string: content.value)) { image in
                            image.resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: 200, maxHeight: 200)
                        } placeholder: {
                            ProgressView()
                        }
                    case .imageData:
                        if let data = content.imageData {
                            #if canImport(UIKit)
                            if let uiImage = UIImage(data: data) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxWidth: 200, maxHeight: 200)
                            }
                            #elseif canImport(AppKit)
                            if let nsImage = NSImage(data: data) {
                                Image(nsImage: nsImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxWidth: 200, maxHeight: 200)
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
                message.isUser ? 
                Color.accentColor : 
                Color(.controlBackgroundColor)
            )
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
            
            if !message.isUser {
                Spacer()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }
}

struct MessageView_Previews: PreviewProvider {
    static func solidColorImage(color: NSColor, size: NSSize = NSSize(width: 200, height: 200)) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        color.drawSwatch(in: NSRect(origin: .zero, size: size))
        image.unlockFocus()
        return image
    }
    
    static var previews: some View {
        let redImage = solidColorImage(color: .systemRed)
        let blueImage = solidColorImage(color: .systemBlue)
        
        Group {
            // 用户文本消息
            MessageView(message: ChatMessage(
                contents: [ChatContent.text("你好！这是一条用户消息")],
                isUser: true
            ))
            .previewDisplayName("用户文本消息")
            
            // 系统文本消息
            MessageView(message: ChatMessage(
                contents: [ChatContent.text("您好，这是系统回复的消息")],
                isUser: false
            ))
            .previewDisplayName("系统文本消息")
            
            // 用户图片消息
            MessageView(message: ChatMessage(
                contents: [ChatContent.imageData(redImage.tiffRepresentation!)],
                isUser: true
            ))
            .previewDisplayName("用户图片消息")
            
            // 系统图片消息
            MessageView(message: ChatMessage(
                contents: [ChatContent.imageData(blueImage.tiffRepresentation!)],
                isUser: false
            ))
            .previewDisplayName("系统图片消息")
            
            // 混合内容消息
            MessageView(message: ChatMessage(
                contents: [
                    ChatContent.text("看看这张图片"),
                    ChatContent.imageData(redImage.tiffRepresentation!)
                ],
                isUser: true
            ))
            .previewDisplayName("混合内容消息")
            
            // 思考状态消息
            MessageView(message: ChatMessage(
                contents: [ChatContent.thinking("正在思考中...")],
                isUser: false,
                isProcessing: true
            ))
            .previewDisplayName("思考状态消息")
        }
        .frame(width: 400)
        .padding()
    }
}