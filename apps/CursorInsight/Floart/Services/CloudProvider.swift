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

    func analyze(text: String, context: String?, styleFragment: String?, conversationFragment: String?) async throws -> String {
        let prompt = systemPrompt(styleFragment: styleFragment, conversationFragment: conversationFragment)
        switch apiType {
        case .claude:
            return try await callClaude(text: text, context: context, prompt: prompt)
        case .openai:
            return try await callOpenAI(text: text, context: context, prompt: prompt)
        case .gemini:
            return try await callGemini(text: text, context: context, prompt: prompt)
        }
    }

    func rawComplete(prompt: String) async throws -> String {
        switch apiType {
        case .claude:
            return try await rawCallClaude(prompt: prompt)
        case .openai:
            return try await rawCallOpenAI(prompt: prompt)
        case .gemini:
            return try await rawCallGemini(prompt: prompt)
        }
    }

    // MARK: - Raw completion (no system prompt, no "屏幕内容" wrapper)

    private func rawCallClaude(prompt: String) async throws -> String {
        let url = URL(string: endpoint)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        let body: [String: Any] = [
            "model": model, "max_tokens": 2048,
            "messages": [["role": "user", "content": prompt]],
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, _) = try await URLSession.shared.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let content = (json?["content"] as? [[String: Any]])?.first
        return content?["text"] as? String ?? ""
    }

    private func rawCallGemini(prompt: String) async throws -> String {
        var components = URLComponents(string: "\(endpoint)/v1beta/models/\(model):generateContent")!
        components.queryItems = [URLQueryItem(name: "key", value: apiKey)]
        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "contents": [["parts": [["text": prompt]]]],
            "generationConfig": ["maxOutputTokens": 2048],
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, _) = try await URLSession.shared.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let candidates = json?["candidates"] as? [[String: Any]]
        let content = candidates?.first?["content"] as? [String: Any]
        let parts = content?["parts"] as? [[String: Any]]
        return parts?.first?["text"] as? String ?? ""
    }

    private func rawCallOpenAI(prompt: String) async throws -> String {
        let url = URL(string: endpoint)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        let body: [String: Any] = [
            "model": model,
            "messages": [["role": "user", "content": prompt]],
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, _) = try await URLSession.shared.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let choices = json?["choices"] as? [[String: Any]]
        let message = choices?.first?["message"] as? [String: Any]
        return message?["content"] as? String ?? ""
    }

    private func systemPrompt(styleFragment: String?, conversationFragment: String?) -> String {
        let base =
        """
        用户在看屏幕。你帮他：1)两三句话总结要点 2)写一条行动项。

        行动项按场景：聊天→回复草稿，会议→一个好问题，文档→一句笔记，代码→改进建议。

        [我]是用户发的，[对方]是对方发的。回复草稿必须模仿[我]的说话风格，接着[对方]最后说的往下聊。不要写标题，不要分析，不要翻译。
        """
        var result = base
        if let style = styleFragment {
            result += "\n\n" + style
        }
        if let conv = conversationFragment {
            result += "\n\n" + conv
        }
        return result
    }

    private func userPrompt(text: String, context: String?) -> String {
        var prompt = "屏幕内容：\n\(text)"
        if let context {
            prompt = "上一轮建议：\(context)\n\n\(prompt)"
        }
        return prompt
    }

    private func callClaude(text: String, context: String?, prompt: String) async throws -> String {
        let url = URL(string: endpoint)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 2048,
            "system": prompt,
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

    private func callGemini(text: String, context: String?, prompt: String) async throws -> String {
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
                "parts": [["text": prompt]]
            ],
            "contents": [
                ["parts": [["text": userPrompt(text: text, context: context)]]]
            ],
            "generationConfig": [
                "maxOutputTokens": 2048,
                "thinkingConfig": [
                    "thinkingBudget": 256
                ] as [String: Any]
            ] as [String: Any],
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

    private func callOpenAI(text: String, context: String?, prompt: String) async throws -> String {
        let url = URL(string: endpoint)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": prompt],
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
