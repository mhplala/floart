// CursorInsight/CursorInsightApp.swift
import SwiftUI
import AppKit
import SwiftData

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}

@main
struct CursorInsightApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var orchestrator = InsightOrchestrator()
    @State private var isExpanded = false
    @State private var panelController = FloatingPanelController()

    // Settings bindings
    @AppStorage("captureMode") private var captureMode: String = CaptureMode.fixedArea.rawValue
    @AppStorage("captureSize") private var captureSize: Double = 2000
    @AppStorage("captureInterval") private var captureInterval: Double = 5
    @AppStorage("analysisInterval") private var analysisInterval: Double = 20
    @AppStorage("aiBackend") private var aiBackend: String = "ollama"
    @AppStorage("ollamaURL") private var ollamaURL: String = "http://localhost:11434"
    @AppStorage("ollamaModel") private var ollamaModel: String = "gemma4:e4b"
    @AppStorage("cloudAPIType") private var cloudAPIType: String = CloudAPIType.claude.rawValue
    @AppStorage("cloudAPIKey") private var cloudAPIKey: String = ""
    @AppStorage("cloudModel") private var cloudModel: String = "claude-sonnet-4-6-20250514"
    @AppStorage("cloudEndpoint") private var cloudEndpoint: String = "https://api.anthropic.com/v1/messages"

    // Shared SwiftData model container
    private let modelContainer: ModelContainer = {
        let schema = Schema([InsightRecord.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        return try! ModelContainer(for: schema, configurations: [config])
    }()

    var body: some Scene {
        MenuBarExtra("CursorInsight", systemImage: orchestrator.isRunning ? "brain.head.profile.fill" : "brain.head.profile") {
            Toggle(orchestrator.isRunning ? "Running" : "Paused", isOn: Binding(
                get: { orchestrator.isRunning },
                set: { newValue in
                    if newValue {
                        configureOrchestrator()
                        orchestrator.start()
                    } else {
                        orchestrator.stop()
                    }
                }
            ))
            .task {
                // Auto-start on first launch
                configureOrchestrator()
                orchestrator.start()
            }
            Button(isExpanded ? "Collapse Panel" : "Expand Panel") {
                togglePanel()
            }
            Divider()
            Button("Open Today's Archive") {
                openTodaysArchive()
            }
            Divider()
            Button("Settings...") {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            }.keyboardShortcut(",")
            Divider()
            Button("Quit") {
                orchestrator.stop()
                NSApp.terminate(nil)
            }.keyboardShortcut("q")
        }

        Settings {
            SettingsView()
        }
        .modelContainer(modelContainer)
    }

    private func configureOrchestrator() {
        orchestrator.captureMode = CaptureMode(rawValue: captureMode) ?? .fixedArea
        orchestrator.captureSize = captureSize
        orchestrator.captureInterval = captureInterval
        orchestrator.analysisInterval = analysisInterval

        // Configure AI
        if aiBackend == "ollama" {
            orchestrator.aiEngine.primaryProvider = OllamaProvider(
                baseURL: ollamaURL, model: ollamaModel
            )
        } else {
            let cloud = CloudProvider(
                apiType: CloudAPIType(rawValue: cloudAPIType) ?? .claude,
                apiKey: cloudAPIKey,
                model: cloudModel,
                endpoint: cloudEndpoint
            )
            orchestrator.aiEngine.primaryProvider = cloud
            orchestrator.aiEngine.fallbackProvider = OllamaProvider(
                baseURL: ollamaURL, model: ollamaModel
            )
        }

        // Configure storage
        let archiveDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("CursorInsight/archive")
        orchestrator.storageManager = StorageManager(archiveDirectory: archiveDir)

        // Wire SwiftData model context
        orchestrator.modelContext = ModelContext(modelContainer)
    }

    private func togglePanel() {
        isExpanded.toggle()
        if isExpanded {
            let panelView = InsightPanelView(
                orchestrator: orchestrator,
                onCollapse: { togglePanel() }
            )
            panelController.show(panelView, size: NSSize(width: 320, height: 400))
        } else {
            let capsuleView = CapsuleView(
                isRunning: orchestrator.isRunning,
                onTap: { togglePanel() }
            )
            panelController.show(capsuleView, size: NSSize(width: 80, height: 40))
        }
    }

    private func openTodaysArchive() {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let today = dateFormatter.string(from: Date())
        let archiveDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("CursorInsight/archive")
        let filePath = archiveDir.appendingPathComponent("\(today).md")

        // Create file if it doesn't exist so we can open it
        if !FileManager.default.fileExists(atPath: filePath.path) {
            let header = StorageManager.dailyHeader(for: today)
            try? header.write(to: filePath, atomically: true, encoding: .utf8)
        }

        NSWorkspace.shared.open(filePath)
    }
}
