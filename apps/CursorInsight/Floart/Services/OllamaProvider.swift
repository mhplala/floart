// Floart/Services/OllamaProvider.swift
import Foundation

struct OllamaProvider: AIProvider {
    let baseURL: String
    let model: String

    var providerName: String { "ollama" }
    var modelName: String { model }

    func analyze(
        text: String,
        context: String?,
        styleFragment: String?,
        conversationFragment: String?,
        sceneType: SceneType,
        inputHint: String?
    ) async throws -> String {
        let url = URL(string: "\(baseURL)/api/generate")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var systemPrompt = """
        用户在看屏幕上的文字。当前场景已由系统判定为：\(sceneType.label)。

        严格按以下格式输出，不要加任何标题：

        （第一段：2-3 句话总结要点，不要写"总结"二字）

        （空一行，写一句 learning：一个深刻洞察、反直觉的规律、或容易被忽略的关键细节。没有就不写这行）

        （空一行，然后输出一行以 |ACTION| 开头的动作，按下面的"动作指示"撰写）

        动作指示（写在 |ACTION| 后面，不要重复这段话）：
        \(sceneType.actionInstruction)

        严格规则：
        - |ACTION| 后面只写能直接使用的纯文本。不加任何前缀、标签、引号、括号说明或"好的"之类的开场白。
        - 不要写"总结""要点""行动项"等标题。
        - 不要翻译。
        - 不要 markdown 符号。
        - 总长度 300 字以内。
        """
        if let hint = inputHint, !hint.isEmpty {
            systemPrompt += "\n\n当前输入框提示：\(hint)"
        }
        if let style = styleFragment {
            systemPrompt += "\n\n" + style
        }
        if let conv = conversationFragment {
            systemPrompt += "\n\n" + conv
        }

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
