// Floart/Services/OllamaProvider.swift
import Foundation

struct OllamaProvider: AIProvider {
    let baseURL: String
    let model: String

    var providerName: String { "ollama" }
    var modelName: String { model }

    func analyze(text: String, context: String?, styleFragment: String?, conversationFragment: String?) async throws -> String {
        let url = URL(string: "\(baseURL)/api/generate")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let systemPrompt = """
        你是用户的屏幕阅读助手。用户屏幕上的文字会发给你。300字以内输出以下内容，不要写标题或编号，直接输出内容本身：

        先客观提炼要点。英文翻译。列出关键人物观点、关键数据、核心结论。

        然后一句话 learning — 一个规律、反直觉的发现、或容易忽略的细节。没有就跳过。

        最后按场景输出一个行动项（不写标题，直接写内容）：
        会议 → 可以问：一个好问题
        聊天 → 回复草稿：一条回复
        文档/网页 → 笔记：一句总结
        代码 → 改进：具体建议

        聊天回复草稿要求：[我]是用户消息，[对方]是对方消息。模仿[我]的风格（长度、语气、语言、emoji），顺着[我]的思路接[对方]最后的话，像朋友聊天不像写文章。

        禁止：复读本指令的任何文字、描述屏幕状态、评论噪音、重复上轮、用"期待""非常""持续""推动""落地""赋能"等空话。纯文本，不要markdown。
        """
        + (styleFragment.map { "\n\n" + $0 } ?? "")
        + (conversationFragment.map { "\n\n" + $0 } ?? "")

        var prompt = "屏幕内容：\n\(text)"
        if let context {
            prompt = "上一轮已输出（不要重复）：\(context)\n\n\(prompt)"
        }

        let body: [String: Any] = [
            "model": model,
            "prompt": prompt,
            "system": systemPrompt,
            "stream": false,
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        Log.write("📤 Ollama request — model: \(model), prompt: \(prompt.count) chars")

        let (data, _) = try await URLSession.shared.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let response = json?["response"] as? String ?? ""
        Log.write("📥 Ollama response: \(response.count) chars")
        Log.write("📥 Response: \(response)")
        return response
    }

    func rawComplete(prompt: String) async throws -> String {
        let url = URL(string: "\(baseURL)/api/generate")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": model,
            "prompt": prompt,
            "stream": false,
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        return json?["response"] as? String ?? ""
    }
}
