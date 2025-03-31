import SwiftUI
import Foundation

@MainActor class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isLoading = false

    // 私有方法处理公共发送逻辑
    private func sendCommonLogic(contents: [ChatContent], using provider: LLMProvider) async throws {
        let messages = await MainActor.run {
            let userMessage = ChatMessage(contents: contents, isUser: true)
            self.messages.append(userMessage)
            
            let aiMessage = ChatMessage(contents: [.text("")], isUser: false, isProcessing: true)
            self.messages.append(aiMessage)
            
            return self.messages.map { $0.toMessage() }
        }

        let lastIndex = self.messages.indices.last!
        
        do {
            for try await message in try await provider.send(messages: messages) {
                await MainActor.run {
                    self.messages[lastIndex] = ChatMessage(from: message)
                }
            }
        } catch {
            await MainActor.run {
                self.messages[lastIndex] = ChatMessage(contents: [.text("处理消息时出错: \(error.localizedDescription)")], isUser: false, isProcessing: false)
            }
            throw error
        }
    }

    // 发送纯文本消息(便捷方法)
    func sendText(_ text: String, using provider: LLMProvider) async throws {
        guard !text.isEmpty else { return }
        try await sendCommonLogic(contents: [.text(text)], using: provider)
    }

    // 发送文本消息
    func sendMessage(text: String, images: [NSImage], using provider: LLMProvider) async throws {
        var contents: [ChatContent] = []
        
        for image in images {
            if let pngData = image.pngData {
                contents.append(.imageData(pngData))
            }
        }
        
        if !text.isEmpty {
            contents.append(.text(text))
        }
        
        try await sendCommonLogic(contents: contents, using: provider)
    }
    
    // 发送图片消息(URL)
    func sendImages(_ urls: [URL], using provider: LLMProvider) async throws {
        guard !urls.isEmpty else { return }
        let contents = urls.map { ChatContent.imageURL($0) }
        try await sendCommonLogic(contents: contents, using: provider)
    }
}
