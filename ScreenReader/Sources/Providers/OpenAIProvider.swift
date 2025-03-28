import Foundation
import Alamofire

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
    private let apiKey: String
    var modelName: String
    
    init(modelName: String, apiKey: String) {
        self.modelName = modelName
        self.apiKey = apiKey
    }
    
    func send(messages: [Message]) async throws -> AsyncThrowingStream<Message, Error> {
        let headers: HTTPHeaders = [
            "Authorization": "Bearer \(apiKey)",
            "Content-Type": "application/json"
        ]
        
        struct OpenAIMessageContent: Codable {
            let type: String
            let text: String?
            let image_url: String?
            
            init(part: ContentPart) {
                switch part.type {
                case .text:
                    self.type = "input_text"
                    self.text = part.value
                    self.image_url = nil
                case .imageURL, .imageData:
                    self.type = "image_url"
                    self.text = nil
                    self.image_url = part.value
                }
            }
        }
        
        struct OpenAIMessage: Codable {
            let role: String
            let content: [OpenAIMessageContent]
        }
        
        struct OpenAIRequest: Codable {
            let model: String
            let messages: [OpenAIMessage]
            let temperature: Double
            let stream: Bool
        }
        
        let request = OpenAIRequest(
            model: modelName,
            messages: messages.map { message in
                OpenAIMessage(
                    role: message.role.rawValue,
                    content: message.content.map { OpenAIMessageContent(part: $0) }
                )
            },
            temperature: 0.7,
            stream: true
        )

        return AsyncThrowingStream { continuation in
            let request = AF.streamRequest(
                "https://api.openai.com/v1/chat/completions",
                method: .post,
                parameters: request,
                encoder: JSONParameterEncoder.default,
                headers: headers,
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
                                    
                                    let message = Message(
                                        role: .assistant,
                                        textContent: content
                                    )
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
                request.cancel()
            }
        }
    }
}
