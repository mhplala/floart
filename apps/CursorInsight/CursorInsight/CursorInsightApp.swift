// CursorInsight/CursorInsightApp.swift
import SwiftUI

@main
struct CursorInsightApp: App {
    @State private var isRunning = true

    var body: some Scene {
        MenuBarExtra("CursorInsight", systemImage: isRunning ? "brain.head.profile.fill" : "brain.head.profile") {
            Toggle(isRunning ? "Running" : "Paused", isOn: $isRunning)
            Divider()
            Button("Settings...") {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            }.keyboardShortcut(",")
            Divider()
            Button("Quit") {
                NSApp.terminate(nil)
            }.keyboardShortcut("q")
        }

        Settings {
            Text("Settings placeholder")
                .frame(width: 400, height: 300)
        }
    }
}
