# CursorInsight — 鼠标周围智能洞察 App

> 日期：2026-04-09
> 位置：`apps/CursorInsight/` (Automemory repo 子项目)
> 技术栈：Swift / SwiftUI / macOS 26+ (Liquid Glass)

## 概述

CursorInsight 是一个 macOS 菜单栏应用（menu bar app），每 5 秒截取鼠标指针周围的屏幕内容，实时 OCR 提取文字，每 20 秒用 AI 生成总结、观察、思考和建议，通过 Liquid Glass 风格的悬浮窗展示结果，并将所有数据存档。

**App 类型：** 菜单栏常驻应用，无主窗口，不出现在 Dock。启动后立即开始截图-分析循环。通过菜单栏图标和悬浮窗与用户交互。

## 架构

纯 Swift 全栈，单进程 .app。

```
┌─────────────────────────────────────────────────┐
│                CursorInsight.app                 │
├─────────────────────────────────────────────────┤
│  ScreenCapture ──▶ OCREngine ──▶ TextBuffer     │
│       (5s)          (实时)        (累积20s)      │
│                                      │          │
│                                      ▼          │
│                                  AIEngine       │
│                                   (20s)         │
│                                      │          │
│                          ┌───────────┴────┐     │
│                          ▼                ▼     │
│                    FloatingPanel    StorageManager│
│                   (Liquid Glass)   (SwiftData+MD)│
└─────────────────────────────────────────────────┘
```

## 模块设计

### 1. ScreenCapture — 截图模块

**两种模式（用户可切换）：**

**固定区域模式：**
- `NSEvent.mouseLocation` 获取鼠标坐标
- `CGWindowListCreateImage` 截取指定矩形区域
- 可配置尺寸：800~3000px，默认 2000x2000
- 边界处理：靠近屏幕边缘时自动偏移

**智能窗口模式：**
- `CGWindowListCopyWindowInfo` 获取鼠标下方窗口
- 截取该窗口完整内容
- 无窗口时 fallback 到固定区域模式

**通用行为：**
- 5 秒间隔（可配置 1~30 秒）
- 鼠标悬停在悬浮窗上时暂停截图（避免截到自己）
- 排除 app 列表支持（如密码管理器）

### 2. OCREngine — 文字识别

- Vision.framework `VNRecognizeTextRequest`
- 识别语言：zh-Hans, zh-Hant, en
- 识别级别：`.accurate`
- 后台线程执行，不阻塞 UI
- 每次结果附带时间戳和鼠标位置

### 3. TextBuffer — 文字缓冲

- 内存滑动窗口，保留最近 20 秒的 OCR 结果
- 相邻两次文本相似度 > 90% 时去重（字符集交集比较）
- 每 20 秒打包缓冲区内容给 AIEngine，然后清空

### 4. AIEngine — AI 分析引擎

**双后端协议：**

```swift
protocol AIProvider {
    func analyze(text: String, context: String?) async throws -> AIResponse
}
```

**实现：**
- `OllamaProvider` — 本地 Ollama（默认 localhost:11434）
- `CloudProvider` — Claude API / OpenAI API（可配置 endpoint + key）

**输入：**
- 当前 20 秒窗口的 OCR 文本
- 上一轮 AI 输出（连续性上下文）

**输出（结构化四部分）：**
1. 总结 — 用户当前在做什么
2. 观察 — 注意到的细节或模式
3. 思考 — 对当前工作的分析和反思
4. 建议 — 可操作的建议或提醒

**AIResponse 模型：**

```swift
struct AIResponse {
    let summary: String
    let observation: String
    let reflection: String
    let suggestion: String
    let timestamp: Date
    let rawText: String
}
```

**容错：**
- 超时 15 秒，超时跳过本轮，保留缓冲区
- Ollama 不可用时提示用户，不崩溃
- Cloud API 失败时回退到 Ollama（如果可用）

### 5. FloatingPanel — Liquid Glass 悬浮窗

**窗口属性：**
- `NSPanel` + `.floating` 级别，始终最前
- `collectionBehavior: .canJoinAllSpaces`，跨桌面可见
- `NSApp.setActivationPolicy(.accessory)`，不出现在 Dock

**折叠态（胶囊）：**
- 半透明 Liquid Glass 材质圆角胶囊
- 小图标 + 运行状态指示
- 可拖动到屏幕任意边缘吸附
- 点击展开

**展开态（信息面板）：**
- Liquid Glass 背景（`.glassEffect` modifier）
- 宽约 320pt，高度自适应
- 四个卡片区域对应 AI 输出四部分
- 内容更新有柔和过渡动画
- 顶部：最小化按钮、暂停/恢复按钮
- 底部：上次更新时间

**交互：**
- 拖动移动位置
- 右键菜单：暂停/恢复、设置、今日存档、退出

### 6. StorageManager — 存储管理

**SwiftData 模型：**

```swift
@Model
class InsightRecord {
    var timestamp: Date
    var mouseX: Double
    var mouseY: Double
    var captureMode: String        // "fixed" | "window"
    var rawOCRText: String
    var summary: String
    var observation: String
    var reflection: String
    var suggestion: String
    var aiProvider: String          // "ollama" | "claude" | "openai"
    var aiModel: String
}
```

**Markdown 导出：**

路径：`apps/CursorInsight/data/archive/{YYYY-MM-DD}.md`

格式：
```markdown
# CursorInsight 日志 — 2026-04-09

## 14:32:05
**总结：** 用户在 VS Code 中编写 SwiftUI 代码
**观察：** 正在实现一个自定义视图修饰符
**思考：** 代码结构清晰，但缺少错误处理
**建议：** 考虑添加 guard 语句处理边界情况

> OCR 原文：
> import SwiftUI ...

---
```

**策略：**
- 每次 AI 产出新结果时同时写入 SwiftData 和追加 Markdown
- Markdown 追加写入，非全量重写
- SwiftData 默认保留 30 天（可配置）
- Markdown 永久保留

### 7. SettingsView — 设置界面

通过菜单栏图标右键或 `Cmd+,` 打开。

**截图设置：**
- 模式切换：固定区域 / 智能窗口
- 固定区域尺寸滑块（800~3000px，默认 2000）
- 截图间隔滑块（1~30 秒，默认 5）
- 排除 app 列表

**AI 设置：**
- 后端切换：Ollama / Cloud API
- Ollama：模型名称、服务地址
- Cloud：provider 选择、API Key、模型选择
- 分析间隔滑块（10~60 秒，默认 20）
- 自定义 system prompt（高级，可折叠）

**存储设置：**
- Markdown 导出路径
- SwiftData 保留天数
- 打开存档文件夹

**通用设置：**
- 开机自启动
- 悬浮窗默认位置
- 全局快捷键：暂停/恢复（默认 `Cmd+Shift+P`）

**持久化：** `@AppStorage` + `UserDefaults`

## 项目结构

```
apps/CursorInsight/
├── CursorInsight.xcodeproj
├── CursorInsight/
│   ├── CursorInsightApp.swift       # App 入口
│   ├── Models/
│   │   ├── InsightRecord.swift      # SwiftData 模型
│   │   └── AIResponse.swift         # AI 响应模型
│   ├── Services/
│   │   ├── ScreenCapture.swift      # 截图服务
│   │   ├── OCREngine.swift          # Vision OCR
│   │   ├── TextBuffer.swift         # 文字缓冲
│   │   ├── AIEngine.swift           # AI 协议 + 调度
│   │   ├── OllamaProvider.swift     # Ollama 实现
│   │   ├── CloudProvider.swift      # Cloud API 实现
│   │   └── StorageManager.swift     # SwiftData + Markdown
│   ├── Views/
│   │   ├── FloatingPanel.swift      # 悬浮窗容器
│   │   ├── CapsuleView.swift        # 折叠态胶囊
│   │   ├── InsightPanelView.swift   # 展开态面板
│   │   └── SettingsView.swift       # 设置界面
│   └── Utilities/
│       └── TextSimilarity.swift     # 文本相似度计算
├── data/
│   └── archive/                     # Markdown 日志
└── README.md
```

## 部署目标

- macOS 26+ (Tahoe) — Liquid Glass 支持
- Xcode 26+
- Swift 6.2+

## 权限需求

- 屏幕录制权限（Screen Recording）— 截图必需
- 辅助功能权限（Accessibility）— 智能窗口模式获取窗口信息
- 网络权限 — 调用 Ollama / Cloud API
