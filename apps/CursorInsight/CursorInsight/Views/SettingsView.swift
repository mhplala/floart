// CursorInsight/Views/SettingsView.swift
import SwiftUI

struct SettingsView: View {
    // Capture
    @AppStorage("captureMode") private var captureMode: String = CaptureMode.fixedArea.rawValue
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
    @AppStorage("analysisInterval") private var analysisInterval: Double = 20

    // Storage
    @AppStorage("retentionDays") private var retentionDays: Double = 30

    var body: some View {
        TabView {
            captureSettings
                .tabItem { Label("Capture", systemImage: "camera") }
            aiSettings
                .tabItem { Label("AI", systemImage: "brain") }
            storageSettings
                .tabItem { Label("Storage", systemImage: "externaldrive") }
        }
        .frame(width: 480, height: 400)
        .padding()
    }

    // MARK: - Capture Tab

    private var captureSettings: some View {
        Form {
            Picker("Mode", selection: $captureMode) {
                Text("Fixed Area").tag(CaptureMode.fixedArea.rawValue)
                Text("Smart Window").tag(CaptureMode.smartWindow.rawValue)
            }

            if captureMode == CaptureMode.fixedArea.rawValue {
                HStack {
                    Text("Size: \(Int(captureSize))px")
                    Slider(value: $captureSize, in: 800...3000, step: 100)
                }
            }

            HStack {
                Text("Interval: \(Int(captureInterval))s")
                Slider(value: $captureInterval, in: 1...30, step: 1)
            }
        }
    }

    // MARK: - AI Tab

    private var aiSettings: some View {
        Form {
            Picker("Backend", selection: $aiBackend) {
                Text("Ollama (Local)").tag("ollama")
                Text("Cloud API").tag("cloud")
            }

            if aiBackend == "ollama" {
                TextField("Ollama URL", text: $ollamaURL)
                TextField("Model", text: $ollamaModel)
            } else {
                Picker("Provider", selection: $cloudAPIType) {
                    Text("Claude").tag(CloudAPIType.claude.rawValue)
                    Text("OpenAI").tag(CloudAPIType.openai.rawValue)
                }
                SecureField("API Key", text: $cloudAPIKey)
                TextField("Model", text: $cloudModel)
                TextField("Endpoint", text: $cloudEndpoint)
            }

            HStack {
                Text("Analysis interval: \(Int(analysisInterval))s")
                Slider(value: $analysisInterval, in: 10...60, step: 5)
            }
        }
    }

    // MARK: - Storage Tab

    private var storageSettings: some View {
        Form {
            HStack {
                Text("Keep records: \(Int(retentionDays)) days")
                Slider(value: $retentionDays, in: 7...365, step: 1)
            }

            Button("Open Archive Folder") {
                let path = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
                    .appendingPathComponent("CursorInsight/archive")
                NSWorkspace.shared.open(path)
            }
        }
    }
}
