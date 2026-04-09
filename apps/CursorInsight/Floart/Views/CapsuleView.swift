// Floart/Views/CapsuleView.swift
import SwiftUI

struct CapsuleView: View {
    let isRunning: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: "brain.head.profile.fill")
                    .font(.system(size: 14))
                Circle()
                    .fill(isRunning ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .capsule)
    }
}
