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
        用户在看屏幕上的文字。你严格按以下格式输出，不要加任何标题：

        （直接写2-3句话总结要点，不要写"总结"二字）

        （空一行，写一句 learning：一个深刻洞察、反直觉的规律、或容易被忽略的关键细节。没有就不写这行）

        （空一行，根据场景写一条行动项，只写对应的一行，以冒号开头）
        如果是聊天，写：回复草稿：xxx
        如果是会议，写：可以问：xxx
        如果是文档/网页，写：笔记：xxx
        如果是代码，写：改进：xxx

        关于聊天回复草稿：[我]是用户发的，[对方]是对方发的。模仿[我]的风格（长度、语气、语言），接着[对方]最后说的往下聊，像朋友发消息。

        不要写"总结""要点""行动项"等标题。不要翻译。不要markdown。300字以内。
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
