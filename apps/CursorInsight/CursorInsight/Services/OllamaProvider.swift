// CursorInsight/Services/OllamaProvider.swift
import Foundation

struct OllamaProvider: AIProvider {
    let baseURL: String
    let model: String

    var providerName: String { "ollama" }
    var modelName: String { model }

    func analyze(text: String, context: String?) async throws -> String {
        let url = URL(string: "\(baseURL)/api/generate")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let systemPrompt = """
        你是一个智能工作助手。根据用户屏幕上的OCR文字内容，提供结构化的分析。
        请严格按以下格式输出：
        **总结：** （用1-2句话描述用户当前在做什么）
        **观察：** （注意到的细节或模式）
        **思考：** （对当前工作的分析和反思）
        **建议：** （可操作的建议或提醒）
        """

        var prompt = "屏幕OCR内容：\n\(text)"
        if let context {
            prompt = "上一轮分析：\n\(context)\n\n\(prompt)"
        }

        let body: [String: Any] = [
            "model": model,
            "prompt": prompt,
            "system": systemPrompt,
            "stream": false,
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        return json?["response"] as? String ?? ""
    }
}
