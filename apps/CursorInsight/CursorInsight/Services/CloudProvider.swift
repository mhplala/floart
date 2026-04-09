// CursorInsight/Services/CloudProvider.swift
import Foundation

enum CloudAPIType: String, Sendable, CaseIterable {
    case claude = "claude"
    case openai = "openai"
}

struct CloudProvider: AIProvider {
    let apiType: CloudAPIType
    let apiKey: String
    let model: String
    let endpoint: String

    func analyze(text: String, context: String?) async throws -> String {
        switch apiType {
        case .claude:
            return try await callClaude(text: text, context: context)
        case .openai:
            return try await callOpenAI(text: text, context: context)
        }
    }

    private var systemPrompt: String {
        """
        你是一个智能工作助手。根据用户屏幕上的OCR文字内容，提供结构化的分析。
        请严格按以下格式输出：
        **总结：** （用1-2句话描述用户当前在做什么）
        **观察：** （注意到的细节或模式）
        **思考：** （对当前工作的分析和反思）
        **建议：** （可操作的建议或提醒）
        """
    }

    private func userPrompt(text: String, context: String?) -> String {
        var prompt = "屏幕OCR内容：\n\(text)"
        if let context {
            prompt = "上一轮分析：\n\(context)\n\n\(prompt)"
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
            "max_tokens": 1024,
            "system": systemPrompt,
            "messages": [
                ["role": "user", "content": userPrompt(text: text, context: context)]
            ],
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let content = (json?["content"] as? [[String: Any]])?.first
        return content?["text"] as? String ?? ""
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

        let (data, _) = try await URLSession.shared.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let choices = json?["choices"] as? [[String: Any]]
        let message = choices?.first?["message"] as? [String: Any]
        return message?["content"] as? String ?? ""
    }
}
