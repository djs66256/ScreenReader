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
    private let config: AgentConfig
    private let isCompatibleMode: Bool  // 新增兼容模式标志
    
    private var apiKey: String? {
        config.provider?.apiKey
    }

    var modelName: String? {
        config.model?.modelName
    }

    var baseURLString: String? {
        config.provider?.defaultBaseURL
    }
    
    init(config: AgentConfig, isCompatibleMode: Bool = false) {
        self.config = config
        self.isCompatibleMode = isCompatibleMode
    }
    
    func send(messages: [Message]) async throws -> AsyncThrowingStream<Message, Error> {
        guard let apiKey = apiKey else {
            throw NSError(domain: "OpenAIProvider", code: 401, userInfo: [NSLocalizedDescriptionKey: "API key is not configured"])
        }
        guard let modelName = modelName else {
            throw NSError(domain: "OpenAIProvider", code: 400, userInfo: [NSLocalizedDescriptionKey: "Model name is not configured"])
        }
        
        // 补全Chat接口路径
        let url: URL
        if isCompatibleMode {
            // 兼容模式下直接使用baseURL作为完整URL
            guard let baseURL = URL(string: baseURLString ?? "") else {
                throw NSError(domain: "OpenAIProvider", code: 400, userInfo: [NSLocalizedDescriptionKey: "API URL is not configured"])
            }
            url = baseURL
        } else {
            // 非兼容模式下追加chat/completions路径
            guard let baseURL = URL(string: baseURLString ?? "") else {
                throw NSError(domain: "OpenAIProvider", code: 400, userInfo: [NSLocalizedDescriptionKey: "API URL is not configured"])
            }
            url = baseURL.appendingPathComponent("chat/completions")
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
                
                #if DEBUG
                var logOutput = ""
                for message in openAIMessages {
                    let role = message["role"] as? String ?? "unknown"
                    if let content = message["content"] as? String {
                        logOutput += "\(role): \(content)\n"
                    } else if let contents = message["content"] as? [[String: String]] {
                        let imageCount = contents.filter { $0["type"] == "image_url" }.count
                        let textContents = contents.compactMap { $0["text"] }.joined(separator: " ")
                        logOutput += "\(role): [\(String(repeating: "image, ", count: imageCount).dropLast(2))] \(textContents)\n"
                    }
                }
                os_log(.debug, "[LLM Message]:\n%{public}@", logOutput)
                #endif
                
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
