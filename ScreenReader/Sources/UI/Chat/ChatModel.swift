import Foundation

enum MessageContent {
    case text(String)  // 普通文本和Markdown统一处理
    case images([URL]) // 支持多张图片
    case system(String) // 系统消息，通常用于显示系统通知或状态更新
    
    // 统一文本处理
    var textContent: String? {
        switch self {
        case .text(let text), .system(let text):
            return text
        case .images:
            return nil
        }
    }
}

struct ChatContent: Identifiable, Equatable {
    let id = UUID()
    let type: ContentType
    let value: String
    var imageData: Data?
    
    static func == (lhs: ChatContent, rhs: ChatContent) -> Bool {
        lhs.id == rhs.id &&
        lhs.type == rhs.type &&
        lhs.value == rhs.value &&
        lhs.imageData == rhs.imageData
    }
    
    enum ContentType: String, Equatable {
        case text
        case imageURL
        case imageData
        case thinking
    }
    
    static func text(_ text: String) -> ChatContent {
        return ChatContent(type: .text, value: text)
    }
    
    static func imageURL(_ url: URL) -> ChatContent {
        return ChatContent(type: .imageURL, value: url.absoluteString)
    }
    
    static func imageData(_ data: Data, format: String = "jpeg") -> ChatContent {
        return ChatContent(type: .imageData, value: "data:image/\(format);base64,", imageData: data)
    }
    
    static func thinking(_ text: String) -> ChatContent {
        return ChatContent(type: .thinking, value: text)
    }
}

struct ChatMessage: Identifiable, Equatable {
    let id = UUID()
    var contents: [ChatContent] // 支持复合内容
    let isUser: Bool
    let timestamp: Date
    var isProcessing: Bool = false
    
    init(contents: [ChatContent], isUser: Bool, timestamp: Date = Date(), isProcessing: Bool = false) {
        self.contents = contents
        self.isUser = isUser
        self.timestamp = timestamp
        self.isProcessing = isProcessing
    }
    
    // 添加内容的方法
    mutating func appendText(_ text: String) {
        contents.append(ChatContent(type: .text, value: text))
    }
    
    mutating func appendImage(_ url: URL) {
        contents.append(ChatContent(type: .imageURL, value: url.absoluteString))
    }
    
    mutating func appendThinking(_ text: String) {
        contents.append(ChatContent(type: .thinking, value: text))
    }
    
    static func == (lhs: ChatMessage, rhs: ChatMessage) -> Bool {
        lhs.id == rhs.id &&
        lhs.contents == rhs.contents &&
        lhs.isUser == rhs.isUser &&
        lhs.timestamp == rhs.timestamp &&
        lhs.isProcessing == rhs.isProcessing
    }
}

extension ChatMessage {
    // 从Message转换为ChatMessage
    init(from message: Message) {
        let contents = message.content.map { part -> ChatContent in
            switch part.type {
            case .text:
                return ChatContent(type: .text, value: part.value)
            case .imageURL:
                return ChatContent(type: .imageURL, value: part.value)
            case .imageData:
                return ChatContent(type: .imageData, value: part.value)
            }
        }
        
        self.init(
            contents: contents,
            isUser: message.role == .user,
            timestamp: message.timestamp,
            isProcessing: false
        )
    }
    
    // 转换为Message
    func toMessage() -> Message {
        let contentParts = contents.compactMap { content -> ContentPart? in
            switch content.type {
            case .text:
                return ContentPart(type: .text, value: content.value)
            case .imageURL:
                return ContentPart(type: .imageURL, value: content.value)
            case .imageData:
                guard let data = content.imageData else { return nil }
                let base64 = data.base64EncodedString()
                return ContentPart(type: .imageData, value: base64) // 简化base64处理
            case .thinking:
                return nil
            }
        }
        
        return Message(
            role: isUser ? .user : .assistant,
            contentParts: contentParts,
            timestamp: timestamp
        )
    }
}
