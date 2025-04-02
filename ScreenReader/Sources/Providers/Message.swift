import Foundation

enum MessageRole: String, Codable {
    case system
    case user
    case assistant
}

enum ContentType: String, Codable {
    case text
    case imageURL
    case imageData
}


/*
openai 传参示例：
文字：
[
   {
     "role": "developer",
     "content": "You are a helpful assistant."
   },
   {
     "role": "user",
     "content": "Hello!"
   }
 ]
 图片：
{
    "role": "user",
    "content": [
        {
            "type": "input_text", "text": "what's in this image?"
        },
        {
            "type": "input_image",
            "image_url": f"data:image/jpeg;base64,{base64_image}",
        },
        {
            "type": "input_image",
            "image_url": "https://upload.wikimedia.org/wikipedia/commons/thumb/d/dd/Gfp-wisconsin-madison-the-nature-boardwalk.jpg/2560px-Gfp-wisconsin-madison-the-nature-boardwalk.jpg",
        },
    ]
}
*/
struct Message {

    enum MessageContent {
        case singleText(String)
        case multiModal([ContentPart])

        struct ContentPart {
            let type: ContentType
            let value: String

            // 添加图片内容的便捷初始化方法
            static func image(_ url: String, isBase64: Bool = false) -> ContentPart {
                return ContentPart(
                    type: isBase64 ? .imageData : .imageURL,
                    value: isBase64 ? "data:image/jpeg;base64,\(url)" : url
                )
            }
        }
    }

    let role: MessageRole
    var content: MessageContent
    let timestamp: Date

    init(role: MessageRole, content: MessageContent, timestamp: Date = Date()) {
        self.role = role
        self.content = content
        self.timestamp = timestamp
    }

    // 纯文本初始化
    init(role: MessageRole, text: String, timestamp: Date = Date()) {
        self.role = role
        self.content = .singleText(text)
        self.timestamp = timestamp
    }
    
    // 单图片初始化
    init(role: MessageRole, imageURL: String, isBase64: Bool = false, timestamp: Date = Date()) {
        self.role = role
        self.content = .multiModal([.image(imageURL, isBase64: isBase64)])
        self.timestamp = timestamp
    }
    
    // 多模态初始化
    init(role: MessageRole, contentParts: [MessageContent.ContentPart], timestamp: Date = Date()) {
        self.role = role
        self.content = .multiModal(contentParts)
        self.timestamp = timestamp
    }

}
