// Floart/Utilities/GlassCompat.swift
import SwiftUI

/// Uses Liquid Glass on macOS 26+, falls back to ultraThinMaterial on older versions.
struct GlassOrMaterial: ViewModifier {
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content
                .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius, style: .continuous))
        } else {
            content
                .background(.ultraThinMaterial)
                .clipShape(.rect(cornerRadius: cornerRadius))
                .shadow(color: .black.opacity(0.1), radius: 12, y: 4)
        }
    }
}

/// Suppresses window launch on macOS 26+, no-op on older.
extension Scene {
    func suppressLaunchIfAvailable() -> some Scene {
        if #available(macOS 26.0, *) {
            return self.defaultLaunchBehavior(.suppressed)
        } else {
            return self
        }
    }
}

struct GlassOrMaterialCapsule: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content
                .glassEffect(.regular.interactive(), in: .capsule)
        } else {
            content
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.1), radius: 8, y: 2)
        }
    }
}
