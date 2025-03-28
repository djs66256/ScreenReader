import SwiftUI
import Foundation

class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isLoading = false
    
    // 发送文本消息
    func sendText(_ text: String) {
        guard !text.isEmpty else { return }
        let message = ChatMessage(
            contents: [.text(text)],
            isUser: true
        )
        appendMessage(message)
    }
    
    // 发送图片消息(URL)
    func sendImages(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        let contents = urls.map { ChatContent.imageURL($0) }
        let message = ChatMessage(
            contents: contents,
            isUser: true
        )
        appendMessage(message)
    }
    
    // 新增私有方法处理消息追加逻辑
    private func appendMessage(_ message: ChatMessage) {
        messages.append(message)
        processAIResponse(for: message)
    }
    
    // 优化AI回复处理
    private func processAIResponse(for userMessage: ChatMessage) {
        isLoading = true
        
        let thinkingMessage = ChatMessage(
            contents: [],
            isUser: false,
            isProcessing: true
        )
        messages.append(thinkingMessage)
        
        Task { @MainActor in
            defer { isLoading = false }
            
            do {
                try await Task.sleep(nanoseconds: 1_000_000_000)
                let response = try await generateAIResponse(for: userMessage)
                
                messages.removeAll { $0.id == thinkingMessage.id }
                messages.append(response)
            } catch {
                handleError(error)
            }
        }
    }
    
    // 新增错误处理方法
    private func handleError(_ error: Error) {
        let errorMessage = ChatMessage(
            contents: [.text("处理消息时出错: \(error.localizedDescription)")],
            isUser: false,
            isProcessing: false
        )
        messages.append(errorMessage)
    }
    
    // 发送图片消息(Data)
    func sendImageData(_ data: Data) {
        let message = ChatMessage(
            contents: [.imageData(data)],
            isUser: true
        )
        messages.append(message)
        processAIResponse(for: message)
    }
    
    // 生成AI回复(示例)
    private func generateAIResponse(for message: ChatMessage) -> ChatMessage {
        let responseText = "这是根据您的消息生成的回复"
        return ChatMessage(
            contents: [.text(responseText)],
            isUser: false
        )
    }
}
