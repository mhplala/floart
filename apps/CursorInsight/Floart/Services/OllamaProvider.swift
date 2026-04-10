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
        用户在看屏幕。你帮他：1)两三句话总结要点 2)写一条行动项。

        行动项按场景：聊天→回复草稿，会议→一个好问题，文档→一句笔记，代码→改进建议。

        [我]是用户发的，[对方]是对方发的。回复草稿必须模仿[我]的说话风格，接着[对方]最后说的往下聊。不要写标题，不要分析，不要翻译。
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
