// Floart/Models/SceneType.swift
import Foundation

/// What the user is doing right now, determined from the frontmost app and
/// the currently focused text input. Drives the kind of action Floart produces.
enum SceneType: String, Sendable {
    case dmChat       // 回复消息
    case meeting      // 可以问
    case document     // 评论
    case vibeCoding   // Prompt for an AI coding assistant
    case codeEditor   // 改进建议
    case search       // 猜搜
    case note         // 笔记 (fallback)

    /// Short label used in logs and (optionally) UI debug strings.
    var label: String {
        switch self {
        case .dmChat:     return "回复"
        case .meeting:    return "提问"
        case .document:   return "评论"
        case .vibeCoding: return "Prompt"
        case .codeEditor: return "改进"
        case .search:     return "猜搜"
        case .note:       return "笔记"
        }
    }

    /// Instruction injected into the LLM system prompt describing what to
    /// write on the action line. Output must be directly usable text — no
    /// prefix, no label, no quotes, no explanation.
    var actionInstruction: String {
        switch self {
        case .dmChat:
            return "写一条用户可以直接发出去的聊天回复。模仿 [我] 的风格（长度、语气、语言），接着 [对方] 最后说的往下聊，像朋友发消息。"
        case .meeting:
            return "写一个用户此刻可以直接在会议上问出口的问题。一句话，口语化，针对当前讨论最关键的点。"
        case .document:
            return "写一条可以直接贴在文档里的评论。聚焦一个具体的点，提出建议、疑问或修改意见。"
        case .vibeCoding:
            return "写一条用户可以直接发给 AI coding 助手的 prompt。具体、可执行，包含目标和必要约束。"
        case .codeEditor:
            return "写一条对当前代码的具体改进建议：指出问题在哪、为什么、怎么改。"
        case .search:
            return "根据用户正在看的内容，猜用户最可能想搜的查询词。只输出纯搜索词。"
        case .note:
            return "写一条值得记下的笔记：一个关键事实、一个洞察、或一个晚点值得回顾的问题。"
        }
    }
}
