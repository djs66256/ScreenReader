import Foundation

struct TemplateParser {
    static func parse(template: String, context: [String: Any]) -> String {
        var result = template
        
        for (key, value) in context {
            let placeholder = "{{\(key)}}"
            result = result.replacingOccurrences(of: placeholder, with: String(describing: value))
        }
        
        return result
    }
}

// 示例用法
// let template = "你好，{{name}}！今天是{{day}}。"
// let context = ["name": "张三", "day": "星期一"]
// let result = TemplateParser.parse(template: template, context: context)
// print(result) // 输出: "你好，张三！今天是星期一。"