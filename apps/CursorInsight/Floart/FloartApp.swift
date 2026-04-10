// Floart/FloartApp.swift
import SwiftUI
import AppKit
import SwiftData

private extension Double {
    var nonZero: Double? { self == 0 ? nil : self }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    var startPipeline: (() -> Void)?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        Log.write("🟢 AppDelegate: applicationDidFinishLaunching")
        // Delay to let SwiftUI set up the startPipeline callback
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [self] in
            startPipeline?()
        }
    }

    static let reopenNotification = Notification.Name("FloartReopenApp")

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            NotificationCenter.default.post(name: AppDelegate.reopenNotification, object: nil)
        }
        return true
    }
}

@main
struct FloartApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var orchestrator = InsightOrchestrator()
    @State private var isExpanded = false
    @State private var panelController = FloatingPanelController()
    @State private var hasStarted = false
    @State private var shouldAutoStart = false

    // Settings bindings
    @AppStorage("captureMode") private var captureMode: String = CaptureMode.smartWindow.rawValue
    @AppStorage("captureSize") private var captureSize: Double = 2000
    @AppStorage("captureInterval") private var captureInterval: Double = 3
    @AppStorage("analysisInterval") private var analysisInterval: Double = 5
    @AppStorage("aiBackend") private var aiBackend: String = "ollama"
    @AppStorage("ollamaURL") private var ollamaURL: String = "http://localhost:11434"
    @AppStorage("ollamaModel") private var ollamaModel: String = "gemma4:e4b"
    @AppStorage("cloudAPIType") private var cloudAPIType: String = CloudAPIType.claude.rawValue
    @AppStorage("cloudAPIKey") private var cloudAPIKey: String = ""
    @AppStorage("cloudModel") private var cloudModel: String = "claude-sonnet-4-6-20250514"
    @AppStorage("cloudEndpoint") private var cloudEndpoint: String = "https://api.anthropic.com/v1/messages"

    // Shared SwiftData model container
    private let modelContainer: ModelContainer = {
        let schema = Schema([InsightRecord.self, DailyReport.self])
        do {
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            Log.write("❌ SwiftData persistent store failed: \(error). Using in-memory.")
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            return try! ModelContainer(for: schema, configurations: [config])
        }
    }()

    private let reportGenerator = DailyReportGenerator()

    init() {
        Log.write("🟢 FloartApp init")
        Task { Log.cleanOldScreenshots() }

        // Use AppDelegate callback for reliable post-launch startup
        let orch = orchestrator
        let panel = panelController
        let container = modelContainer
        let generator = reportGenerator
        appDelegate.startPipeline = {
            Log.write("🟢 Auto-starting pipeline from AppDelegate...")
            // configureOrchestrator inline (can't call self methods from here)
            let defaults = UserDefaults.standard
            orch.captureMode = CaptureMode(rawValue: defaults.string(forKey: "captureMode") ?? "window") ?? .smartWindow
            orch.captureSize = defaults.double(forKey: "captureSize").nonZero ?? 2000
            orch.captureInterval = defaults.double(forKey: "captureInterval").nonZero ?? 5

            let aiBackend = defaults.string(forKey: "aiBackend") ?? "ollama"
            if aiBackend == "ollama" {
                orch.aiEngine.primaryProvider = OllamaProvider(
                    baseURL: defaults.string(forKey: "ollamaURL") ?? "http://localhost:11434",
                    model: defaults.string(forKey: "ollamaModel") ?? "gemma4:e4b"
                )
            } else {
                let cloud = CloudProvider(
                    apiType: CloudAPIType(rawValue: defaults.string(forKey: "cloudAPIType") ?? "claude") ?? .claude,
                    apiKey: defaults.string(forKey: "cloudAPIKey") ?? "",
                    model: defaults.string(forKey: "cloudModel") ?? "gemini-2.5-flash",
                    endpoint: defaults.string(forKey: "cloudEndpoint") ?? "https://generativelanguage.googleapis.com"
                )
                orch.aiEngine.primaryProvider = cloud
                orch.aiEngine.fallbackProvider = OllamaProvider(
                    baseURL: defaults.string(forKey: "ollamaURL") ?? "http://localhost:11434",
                    model: defaults.string(forKey: "ollamaModel") ?? "gemma4:e4b"
                )
            }

            let archiveDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
                .appendingPathComponent("Floart/archive")
            orch.storageManager = StorageManager(archiveDirectory: archiveDir)
            orch.modelContext = ModelContext(container)

            orch.start()

            // Show expanded panel
            let panelView = InsightPanelView(orchestrator: orch, onCollapse: {
                let capsule = CapsuleView(isRunning: orch.isRunning, onTap: {
                    let expanded = InsightPanelView(orchestrator: orch, onCollapse: {})
                    panel.show(expanded)
                })
                panel.show(capsule)
            })
            panel.show(panelView)
            Log.write("🟢 Panel shown")

            // Generate missing daily reports
            Task {
                let ctx = ModelContext(container)
                await generator.generateMissingReports(context: ctx)
            }
        }
    }

    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        MenuBarExtra("Floart", systemImage: orchestrator.isRunning ? "brain.head.profile.fill" : "brain.head.profile") {
            Button("Open Floart") {
                openWindow(id: "main")
                NSApp.activate(ignoringOtherApps: true)
            }
            Divider()
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
            Button(isExpanded ? "Collapse Panel" : "Expand Panel") {
                togglePanel()
            }
            Divider()
            Button("Open Today's Archive") {
                openTodaysArchive()
            }
            Divider()
            SettingsLink {
                Text("Settings...")
            }.keyboardShortcut(",")
            Divider()
            Button("Quit") {
                orchestrator.stop()
                NSApp.terminate(nil)
            }.keyboardShortcut("q")
        }

        Window("Floart", id: "main") {
            MainWindowView()
                .onReceive(NotificationCenter.default.publisher(for: AppDelegate.reopenNotification)) { _ in
                    // Dock icon clicked with no visible windows
                    openWindow(id: "main")
                    NSApp.activate(ignoringOtherApps: true)
                }
        }
        .modelContainer(modelContainer)
        .defaultSize(width: 900, height: 600)
        .defaultPosition(.center)
        .suppressLaunchIfAvailable()

        Settings {
            SettingsView()
                .onChange(of: captureMode) { applySettings() }
                .onChange(of: captureSize) { applySettings() }
                .onChange(of: captureInterval) { applySettingsAndRestart() }
                .onChange(of: aiBackend) { applySettings() }
                .onChange(of: ollamaURL) { applySettings() }
                .onChange(of: ollamaModel) { applySettings() }
                .onChange(of: cloudAPIType) { applySettings() }
                .onChange(of: cloudAPIKey) { applySettings() }
                .onChange(of: cloudModel) { applySettings() }
                .onChange(of: cloudEndpoint) { applySettings() }
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
            .appendingPathComponent("Floart/archive")
        orchestrator.storageManager = StorageManager(archiveDirectory: archiveDir)

        // Wire SwiftData model context
        orchestrator.modelContext = ModelContext(modelContainer)
    }

    /// Apply settings without restarting timers (mode, size, AI config)
    private func applySettings() {
        Log.write("⚙️ Settings changed, applying...")
        configureOrchestrator()
    }

    /// Apply settings and restart timers (interval changes need timer restart)
    private func applySettingsAndRestart() {
        Log.write("⚙️ Interval changed, restarting pipeline...")
        configureOrchestrator()
        if orchestrator.isRunning {
            orchestrator.restart()
        }
    }

    private func showCapsule() {
        isExpanded = false
        let capsuleView = CapsuleView(
            isRunning: orchestrator.isRunning,
            onTap: { togglePanel() }
        )
        panelController.show(capsuleView)
    }

    private func togglePanel() {
        isExpanded.toggle()
        if isExpanded {
            let panelView = InsightPanelView(
                orchestrator: orchestrator,
                onCollapse: { togglePanel() }
            )
            panelController.show(panelView)
        } else {
            showCapsule()
        }
    }

    private func openTodaysArchive() {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let today = dateFormatter.string(from: Date())
        let archiveDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Floart/archive")
        let filePath = archiveDir.appendingPathComponent("\(today).md")

        // Create file if it doesn't exist so we can open it
        if !FileManager.default.fileExists(atPath: filePath.path) {
            let header = StorageManager.dailyHeader(for: today)
            try? header.write(to: filePath, atomically: true, encoding: .utf8)
        }

        NSWorkspace.shared.open(filePath)
    }
}
