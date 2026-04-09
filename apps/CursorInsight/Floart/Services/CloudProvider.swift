// Floart/Services/CloudProvider.swift
import Foundation

enum CloudAPIType: String, Sendable, CaseIterable {
    case claude = "claude"
    case openai = "openai"
    case gemini = "gemini"
}

struct CloudProvider: AIProvider {
    let apiType: CloudAPIType
    let apiKey: String
    let model: String
    let endpoint: String

    var providerName: String { apiType.rawValue }
    var modelName: String { model }

    func analyze(text: String, context: String?) async throws -> String {
        switch apiType {
        case .claude:
            return try await callClaude(text: text, context: context)
        case .openai:
            return try await callOpenAI(text: text, context: context)
        case .gemini:
            return try await callGemini(text: text, context: context)
        }
    }

    private var systemPrompt: String {
        """
        你是用户的屏幕阅读助手。你能看到用户屏幕上的文字（带有空间位置标注和应用名称）。[主内容区]是核心内容，侧边栏可忽略。

        输出严格分三部分，缺一不可：

        第一部分（不要写标题，直接输出内容）：客观准确地提炼内容要点。英文要翻译。列出关键人物的观点、关键数据、核心结论。这部分要事实准确，不加主观判断。

        第二部分（不要写标题，直接输出内容）：用一句话点出一个精辟的 learning。这句话应该让用户学到新东西 — 一个规律、一个反直觉的发现、一个跨领域的类比、或者一个容易忽略的关键细节。不要强行深刻，没有真正的洞察就跳过这部分，不要写"暂无"。

        第三部分按场景（不要写行动标题）：
        会议 → 「可以问：」一个好问题
        聊天 → 「回复草稿：」可直接发送的回复
        文档/网页 → 「笔记：」一句值得记录的总结
        代码 → 「改进：」具体改进建议

        禁止：描述屏幕状态、评论噪音、重复上轮、为赋新词强说愁。
        格式：纯文本，不要markdown。300字以内。用中文。
        """
    }

    private func userPrompt(text: String, context: String?) -> String {
        var prompt = "屏幕内容：\n\(text)"
        if let context {
            prompt = "上一轮建议：\(context)\n\n\(prompt)"
        }
        return prompt
    }

    private func callClaude(text: String, context: String?) async throws -> String {
        let url = URL(string: endpoint)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 2048,
            "system": systemPrompt,
            "messages": [
                ["role": "user", "content": userPrompt(text: text, context: context)]
            ],
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            let body = String(data: data, encoding: .utf8) ?? ""
            Log.write("❌ Claude HTTP \(httpResponse.statusCode): \(body.prefix(300))")
            return ""
        }
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let content = (json?["content"] as? [[String: Any]])?.first
        return content?["text"] as? String ?? ""
    }

    private func callGemini(text: String, context: String?) async throws -> String {
        // Gemini API: POST https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent?key={apiKey}
        var components = URLComponents(string: "\(endpoint)/v1beta/models/\(model):generateContent")!
        components.queryItems = [URLQueryItem(name: "key", value: apiKey)]
        guard let url = components.url else {
            Log.write("❌ Gemini: failed to construct URL from endpoint: \(endpoint)")
            return ""
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "system_instruction": [
                "parts": [["text": systemPrompt]]
            ],
            "contents": [
                ["parts": [["text": userPrompt(text: text, context: context)]]]
            ],
            "generationConfig": [
                "maxOutputTokens": 2048,
            ],
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            let body = String(data: data, encoding: .utf8) ?? ""
            Log.write("❌ Gemini HTTP \(httpResponse.statusCode): \(body.prefix(300))")
            return ""
        }
        let rawString = String(data: data, encoding: .utf8) ?? ""
        Log.write("📥 Gemini raw response: \(rawString.prefix(500))")

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        // Check for errors
        if let error = json?["error"] as? [String: Any] {
            let msg = error["message"] as? String ?? "unknown"
            Log.write("❌ Gemini error: \(msg)")
            return ""
        }

        let candidates = json?["candidates"] as? [[String: Any]]
        let candidate = candidates?.first
        let finishReason = candidate?["finishReason"] as? String ?? "?"
        Log.write("📥 Gemini finishReason: \(finishReason)")

        let content = candidate?["content"] as? [String: Any]
        let parts = content?["parts"] as? [[String: Any]]
        let text = parts?.first?["text"] as? String ?? ""
        Log.write("📥 Gemini text: \(text.count) chars")
        return text
    }

    private func callOpenAI(text: String, context: String?) async throws -> String {
        let url = URL(string: endpoint)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userPrompt(text: text, context: context)],
            ],
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            let body = String(data: data, encoding: .utf8) ?? ""
            Log.write("❌ OpenAI HTTP \(httpResponse.statusCode): \(body.prefix(300))")
            return ""
        }
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let choices = json?["choices"] as? [[String: Any]]
        let message = choices?.first?["message"] as? [String: Any]
        return message?["content"] as? String ?? ""
    }
}
