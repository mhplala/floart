// Floart/Services/OllamaProvider.swift
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
}
