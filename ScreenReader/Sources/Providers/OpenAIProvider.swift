import Foundation
import Alamofire
import os

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
class OpenAIProvider: LLMProvider {
    private let config: LLMProviderConfig
    private let model: LLMModel  // 新增model属性
    
    private var apiKey: String {
        config.apiKey ?? ""
    }
    var modelName: String {
        model.id  // 从LLMModel获取模型ID
    }
    
    init(config: LLMProviderConfig, model: LLMModel) {
        self.config = config
        self.model = model
        guard config.supportedModelIDs.contains(model.id) else {
            fatalError("Unsupported model ID: \(model.id)")
        }
    }
    
    func send(messages: [Message]) async throws -> AsyncThrowingStream<Message, Error> {
        guard let url = URL(string: config.defaultBaseURL ?? "") else {
            fatalError("API URL is not configured")
        }
        
        let headers = [
            "Authorization": "Bearer \(apiKey)",
            "Content-Type": "application/json"
        ]

        struct OpenAIURLRequest: URLRequestConvertible {
            let url: URL
            let headers: [String: String]
            let messages: [Message]
            let modelName: String
            
            func asURLRequest() throws -> URLRequest {
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.allHTTPHeaderFields = headers
                
                let openAIMessages = messages.map { $0.toOpenAIFormat() }
                
                let parameters: [String: Any] = [
                    "model": modelName,
                    "messages": openAIMessages,
                    "stream": true
                ]
                
                request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
                return request
            }
        }

        let request = OpenAIURLRequest(
            url: url,
            headers: headers,
            messages: messages,
            modelName: modelName
        )

        return AsyncThrowingStream { continuation in
            let textLock = OSAllocatedUnfairLock()
            var text = ""
            let dataRequest = AF.streamRequest(
                request,
                automaticallyCancelOnStreamError: true
            )
            .responseStream { stream in
                switch stream.event {
                case let .stream(result):
                    switch result {
                    case let .success(data):
                        do {
                            let lines = String(decoding: data, as: UTF8.self)
                                .components(separatedBy: "\n")
                                .filter { $0.hasPrefix("data:") && $0 != "data: [DONE]" }
                            
                            for line in lines {
                                let jsonString = line.replacingOccurrences(of: "data: ", with: "")
                                if let jsonData = jsonString.data(using: .utf8),
                                   let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                                   let choices = json["choices"] as? [[String: Any]],
                                   let firstChoice = choices.first,
                                   let delta = firstChoice["delta"] as? [String: Any],
                                   let content = delta["content"] as? String {

                                    let message = textLock.withLock {
                                        text += content

                                         return Message(
                                            role: .assistant,
                                            text: text
                                        )
                                    }

                                    continuation.yield(message)
                                }
                            }
                        } catch {
                            continuation.finish(throwing: error)
                        }
                        
                    case let .failure(error):
                        continuation.finish(throwing: error)
                    }
                    
                case let .complete(completion):
                    if let error = completion.error {
                        continuation.finish(throwing: error)
                    } else {
                        continuation.finish()
                    }
                }
            }
            
            continuation.onTermination = { @Sendable _ in
                dataRequest.cancel()
            }
        }
    }
}


extension Message {
    /// 将消息转换为OpenAI API兼容格式
    func toOpenAIFormat() -> [String: Any] {
        var content: Any
        
        switch self.content {
        case .singleText(let text):
            content = text
        case .multiModal(let parts):
            content = parts.map { part in
                switch part.type {
                case .text:
                    return ["type": "text", "text": part.value]
                case .imageURL, .imageData:
                    return ["type": "image_url", "image_url": part.value]
                }
            }
        }
        
        return [
            "role": self.role.rawValue,
            "content": content
        ]
    }
}
