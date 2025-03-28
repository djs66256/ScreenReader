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

struct ContentPart: Codable {
    let type: ContentType
    let value: String  // 文本内容或图片URL/base64编码
}

/*
openai 传参示例：
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
struct Message: Codable {
    let role: MessageRole
    let content: [ContentPart]
    let timestamp: Date // 新增时间戳
    
    // 保持对纯文本的兼容
    init(role: MessageRole, textContent: String, timestamp: Date = Date()) {
        self.role = role
        self.content = [ContentPart(type: .text, value: textContent)]
        self.timestamp = timestamp
    }
    
    // 多模态初始化方法
    init(role: MessageRole, contentParts: [ContentPart], timestamp: Date = Date()) {
        self.role = role
        self.content = contentParts
        self.timestamp = timestamp
    }
    
    func toDictionary() -> [String: Any] {
        return [
            "role": role.rawValue,
            "content": content.map { ["type": $0.type.rawValue, "value": $0.value] },
            "timestamp": timestamp.timeIntervalSince1970 // 转换为时间戳
        ]
    }
}