// Floart/Views/SettingsView.swift
import SwiftUI

struct SettingsView: View {
    // Capture
    @AppStorage("captureMode") private var captureMode: String = CaptureMode.smartWindow.rawValue
    @AppStorage("captureSize") private var captureSize: Double = 2000
    @AppStorage("captureInterval") private var captureInterval: Double = 5

    // AI
    @AppStorage("aiBackend") private var aiBackend: String = "ollama"
    @AppStorage("ollamaURL") private var ollamaURL: String = "http://localhost:11434"
    @AppStorage("ollamaModel") private var ollamaModel: String = "gemma4:e4b"
    @AppStorage("cloudAPIType") private var cloudAPIType: String = CloudAPIType.claude.rawValue
    @AppStorage("cloudAPIKey") private var cloudAPIKey: String = ""
    @AppStorage("cloudModel") private var cloudModel: String = "claude-sonnet-4-6-20250514"
    @AppStorage("cloudEndpoint") private var cloudEndpoint: String = "https://api.anthropic.com/v1/messages"

    // OCR
    @AppStorage("watermarkKeywords") private var watermarkKeywords: String = ""

    // Storage
    @AppStorage("retentionDays") private var retentionDays: Double = 30

    // State
    @State private var connectionStatus: String = ""
    @State private var isTesting = false

    var body: some View {
        TabView {
            captureSettings
                .tabItem { Label("Capture", systemImage: "camera") }
            aiSettings
                .tabItem { Label("AI", systemImage: "brain") }
            storageSettings
                .tabItem { Label("Storage", systemImage: "externaldrive") }
            aboutView
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 500, height: 420)
        .padding()
    }

    // MARK: - Capture Tab

    private var captureSettings: some View {
        Form {
            Section("Capture Mode") {
                Picker("Mode", selection: $captureMode) {
                    Text("Smart Window (Active App)").tag(CaptureMode.smartWindow.rawValue)
                    Text("Fixed Area (Around Cursor)").tag(CaptureMode.fixedArea.rawValue)
                }
                .pickerStyle(.radioGroup)

                if captureMode == CaptureMode.fixedArea.rawValue {
                    LabeledContent("Area Size") {
                        HStack {
                            Slider(value: $captureSize, in: 800...3000, step: 100)
                            Text("\(Int(captureSize))px")
                                .monospacedDigit()
                                .frame(width: 55, alignment: .trailing)
                        }
                    }
                }
            }

            Section("Timing") {
                LabeledContent("Capture Interval") {
                    HStack {
                        Slider(value: $captureInterval, in: 2...30, step: 1)
                        Text("\(Int(captureInterval))s")
                            .monospacedDigit()
                            .frame(width: 35, alignment: .trailing)
                    }
                }
                Text("Lower = more responsive, higher CPU usage")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Watermark Filter") {
                TextField("Keywords (comma separated)", text: $watermarkKeywords)
                    .textFieldStyle(.roundedBorder)
                Text("Auto-detects repeated watermarks (e.g. \"Name 1234\"). Add extra keywords here for precise filtering.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - AI Tab

    private var aiSettings: some View {
        Form {
            Section("AI Backend") {
                Picker("Backend", selection: $aiBackend) {
                    Text("Ollama (Local)").tag("ollama")
                    Text("Cloud API").tag("cloud")
                }
                .pickerStyle(.segmented)
            }

            if aiBackend == "ollama" {
                Section("Ollama Configuration") {
                    TextField("Server URL", text: $ollamaURL)
                        .textFieldStyle(.roundedBorder)
                    TextField("Model Name", text: $ollamaModel)
                        .textFieldStyle(.roundedBorder)
                    Text("Make sure Ollama is running: ollama serve")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Section("Cloud Provider") {
                    Picker("Provider", selection: $cloudAPIType) {
                        Text("Claude").tag(CloudAPIType.claude.rawValue)
                        Text("OpenAI").tag(CloudAPIType.openai.rawValue)
                        Text("Gemini").tag(CloudAPIType.gemini.rawValue)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: cloudAPIType) {
                        applyProviderDefaults()
                        connectionStatus = ""
                    }
                }

                Section("API Configuration") {
                    SecureField("API Key", text: $cloudAPIKey)
                        .textFieldStyle(.roundedBorder)
                    TextField("Model", text: $cloudModel)
                        .textFieldStyle(.roundedBorder)
                    TextField("Endpoint", text: $cloudEndpoint)
                        .textFieldStyle(.roundedBorder)
                        .foregroundStyle(.secondary)
                        .font(.system(size: 11))
                }
            }

            Section {
                HStack {
                    Button(isTesting ? "Testing..." : "Test Connection") {
                        testConnection()
                    }
                    .disabled(isTesting)

                    if !connectionStatus.isEmpty {
                        Text(connectionStatus)
                            .font(.caption)
                            .foregroundStyle(connectionStatus.contains("OK") ? .green : .red)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Storage Tab

    private var storageSettings: some View {
        Form {
            Section("Data Retention") {
                LabeledContent("Keep Records") {
                    HStack {
                        Slider(value: $retentionDays, in: 7...365, step: 1)
                        Text("\(Int(retentionDays)) days")
                            .monospacedDigit()
                            .frame(width: 60, alignment: .trailing)
                    }
                }
                Text("SwiftData records older than this are automatically removed")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Files") {
                HStack {
                    Button("Open Archive Folder") {
                        let path = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
                            .appendingPathComponent("Floart/archive")
                        try? FileManager.default.createDirectory(at: path, withIntermediateDirectories: true)
                        NSWorkspace.shared.open(path)
                    }
                    Button("Open Screenshots Folder") {
                        let path = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
                            .appendingPathComponent("Floart/screenshots")
                        try? FileManager.default.createDirectory(at: path, withIntermediateDirectories: true)
                        NSWorkspace.shared.open(path)
                    }
                }

                HStack {
                    Button("Open Debug Log") {
                        NSWorkspace.shared.open(URL(fileURLWithPath: Log.path))
                    }
                    Button("Clear Screenshots", role: .destructive) {
                        clearScreenshots()
                    }
                }
            }

            Section("Disk Usage") {
                LabeledContent("Screenshots", value: diskUsage(for: "screenshots"))
                LabeledContent("Archives", value: diskUsage(for: "archive"))
                LabeledContent("Debug Log", value: fileSize(at: Log.path))
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - About Tab

    private var aboutView: some View {
        VStack(spacing: 16) {
            Image(systemName: "brain.head.profile.fill")
                .font(.system(size: 48))
                .foregroundStyle(.tint)
            Text("Floart")
                .font(.title)
                .fontWeight(.bold)
            Text("v0.1.0")
                .foregroundStyle(.secondary)
            Text("Your screen reading companion")
                .foregroundStyle(.secondary)

            Divider().padding(.horizontal, 40)

            VStack(alignment: .leading, spacing: 8) {
                Label("Capture: ScreenCaptureKit", systemImage: "camera")
                Label("OCR: Apple Vision", systemImage: "doc.text.viewfinder")
                Label("AI: Ollama / Claude / OpenAI / Gemini", systemImage: "brain")
                Label("UI: SwiftUI + Liquid Glass", systemImage: "sparkles")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Actions

    private func applyProviderDefaults() {
        switch CloudAPIType(rawValue: cloudAPIType) {
        case .claude:
            cloudModel = "claude-sonnet-4-6-20250514"
            cloudEndpoint = "https://api.anthropic.com/v1/messages"
        case .openai:
            cloudModel = "gpt-4o"
            cloudEndpoint = "https://api.openai.com/v1/chat/completions"
        case .gemini:
            cloudModel = "gemini-2.5-flash"
            cloudEndpoint = "https://generativelanguage.googleapis.com"
        case .none:
            break
        }
    }

    private func testConnection() {
        isTesting = true
        connectionStatus = ""
        Task {
            do {
                if aiBackend == "ollama" {
                    let url = URL(string: "\(ollamaURL)/api/tags")!
                    let (_, response) = try await URLSession.shared.data(from: url)
                    if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                        connectionStatus = "OK — Ollama connected"
                    } else {
                        connectionStatus = "Failed — check Ollama URL"
                    }
                } else {
                    // Quick ping based on provider
                    switch CloudAPIType(rawValue: cloudAPIType) {
                    case .gemini:
                        var components = URLComponents(string: "\(cloudEndpoint)/v1beta/models")!
                        components.queryItems = [URLQueryItem(name: "key", value: cloudAPIKey)]
                        let (_, response) = try await URLSession.shared.data(from: components.url!)
                        if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                            connectionStatus = "OK — Gemini API key valid"
                        } else {
                            connectionStatus = "Failed — check API key"
                        }
                    case .claude:
                        // Claude doesn't have a simple ping, just validate key format
                        if cloudAPIKey.hasPrefix("sk-ant-") {
                            connectionStatus = "OK — Key format valid"
                        } else {
                            connectionStatus = "Warning — key should start with sk-ant-"
                        }
                    case .openai:
                        let url = URL(string: "https://api.openai.com/v1/models")!
                        var request = URLRequest(url: url)
                        request.setValue("Bearer \(cloudAPIKey)", forHTTPHeaderField: "Authorization")
                        let (_, response) = try await URLSession.shared.data(for: request)
                        if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                            connectionStatus = "OK — OpenAI API key valid"
                        } else {
                            connectionStatus = "Failed — check API key"
                        }
                    case .none:
                        connectionStatus = "Unknown provider"
                    }
                }
            } catch {
                connectionStatus = "Error: \(error.localizedDescription)"
            }
            isTesting = false
        }
    }

    private func clearScreenshots() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Floart/screenshots")
        if let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) {
            for file in files { try? FileManager.default.removeItem(at: file) }
        }
    }

    private func diskUsage(for subfolder: String) -> String {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Floart/\(subfolder)")
        guard let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.fileSizeKey]) else {
            return "0 files"
        }
        var totalBytes: UInt64 = 0
        for file in files {
            if let size = try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                totalBytes += UInt64(size)
            }
        }
        return "\(files.count) files, \(ByteCountFormatter.string(fromByteCount: Int64(totalBytes), countStyle: .file))"
    }

    private func fileSize(at path: String) -> String {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: path),
              let size = attrs[.size] as? UInt64 else { return "—" }
        return ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
    }
}
