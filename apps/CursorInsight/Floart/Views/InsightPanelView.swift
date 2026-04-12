// Floart/Views/InsightPanelView.swift
import SwiftUI
import AppKit

struct InsightPanelView: View {
    @Bindable var orchestrator: InsightOrchestrator
    let onCollapse: () -> Void
    @State private var copied = false

    private var response: AIResponse { orchestrator.displayedResponse }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            header

            Divider().opacity(0.2)

            // Content
            if response.isEmpty {
                Text("Waiting...")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .padding(14)
            } else {
                contentView
            }

            Divider().opacity(0.2)

            // Footer
            footer
        }
        .frame(width: 300)
        .modifier(GlassOrMaterial(cornerRadius: 16))
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "brain.head.profile.fill")
                .font(.system(size: 13))
            Text("Floart")
                .font(.system(size: 12, weight: .semibold))

            Spacer()

            Button {
                if orchestrator.isRunning { orchestrator.stop() }
                else { orchestrator.start() }
            } label: {
                Image(systemName: orchestrator.isRunning ? "pause.fill" : "play.fill")
                    .font(.system(size: 10))
            }
            .buttonStyle(.plain)

            Button(action: onCollapse) {
                Image(systemName: "minus")
                    .font(.system(size: 10))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    // MARK: - Content

    private var contentView: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Analysis text
            Text(analysisText)
                .font(.system(size: 12))
                .lineSpacing(3)
                .foregroundStyle(.primary.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)

            // Action block — visually distinct with copy button
            if let action = response.actionContent {
                HStack(alignment: .top, spacing: 8) {
                    Text(action)
                        .font(.system(size: 12, weight: .medium))
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)

                    Spacer(minLength: 4)

                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(action, forType: .string)
                        copied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
                    } label: {
                        Image(systemName: copied ? "checkmark.circle.fill" : "doc.on.doc")
                            .font(.system(size: 13))
                            .foregroundStyle(copied ? .green : .secondary)
                    }
                    .buttonStyle(.plain)
                    .help(copied ? "Copied!" : "Copy action")
                }
                .padding(10)
                .background(.quaternary.opacity(0.5))
                .clipShape(.rect(cornerRadius: 8))
            }
        }
        .padding(14)
        .contentTransition(.numericText())
        .animation(.smooth, value: response.advice)
    }

    /// The analysis portion (before the action marker). Recognizes both the new
    /// `|ACTION|` marker and the legacy Chinese-prefix markers.
    private var analysisText: String {
        if let range = response.advice.range(of: "|ACTION|") {
            return String(response.advice[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let legacy = ["回复草稿：", "可以问：", "笔记：", "改进：",
                      "回复草稿:", "可以问:", "笔记:", "改进:"]
        var earliest: String.Index?
        for marker in legacy {
            if let range = response.advice.range(of: marker) {
                if earliest == nil || range.lowerBound < earliest! {
                    earliest = range.lowerBound
                }
            }
        }
        if let cut = earliest {
            return String(response.advice[..<cut]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return response.advice
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 6) {
            Button { orchestrator.showPrevious() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 9))
            }
            .buttonStyle(.plain)
            .disabled(!orchestrator.canGoBack)
            .opacity(orchestrator.canGoBack ? 0.7 : 0.2)

            if orchestrator.historyIndex >= 0 {
                Text("History")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .onTapGesture { orchestrator.showLatest() }
            }

            Button { orchestrator.showNext() } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 9))
            }
            .buttonStyle(.plain)
            .disabled(!orchestrator.canGoForward)
            .opacity(orchestrator.canGoForward ? 0.7 : 0.2)

            Spacer()

            Text(timeString(response.timestamp))
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)

            Circle()
                .fill(orchestrator.isRunning ? Color.green : Color.orange)
                .frame(width: 5, height: 5)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
    }

    private func timeString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f.string(from: date)
    }
}
