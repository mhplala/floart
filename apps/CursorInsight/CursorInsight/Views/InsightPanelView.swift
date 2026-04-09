// CursorInsight/Views/InsightPanelView.swift
import SwiftUI

struct InsightPanelView: View {
    @Bindable var orchestrator: InsightOrchestrator
    let onCollapse: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Image(systemName: "brain.head.profile.fill")
                    .font(.system(size: 16))
                Text("CursorInsight")
                    .font(.headline)
                Spacer()
                Button {
                    if orchestrator.isRunning { orchestrator.stop() }
                    else { orchestrator.start() }
                } label: {
                    Image(systemName: orchestrator.isRunning ? "pause.fill" : "play.fill")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                Button(action: onCollapse) {
                    Image(systemName: "minus")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider().opacity(0.3)

            // Content cards
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    insightCard(icon: "doc.text", title: "总结", text: orchestrator.latestResponse.summary)
                    insightCard(icon: "eye", title: "观察", text: orchestrator.latestResponse.observation)
                    insightCard(icon: "lightbulb", title: "思考", text: orchestrator.latestResponse.reflection)
                    insightCard(icon: "checkmark.seal", title: "建议", text: orchestrator.latestResponse.suggestion)
                }
                .padding(16)
            }

            Divider().opacity(0.3)

            // Footer
            HStack {
                Text(timeString(orchestrator.latestResponse.timestamp))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Circle()
                    .fill(orchestrator.isRunning ? Color.green : Color.orange)
                    .frame(width: 6, height: 6)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .frame(width: 320)
        .glassEffect(.regular, in: .rect(cornerRadius: 20, style: .continuous))
        .contentTransition(.numericText())
        .animation(.smooth, value: orchestrator.latestResponse.summary)
    }

    private func insightCard(icon: String, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(text.isEmpty ? "—" : text)
                    .font(.system(size: 13))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func timeString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return "Updated \(f.string(from: date))"
    }
}
