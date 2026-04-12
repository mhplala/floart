// Floart/Views/BubbleView.swift
import SwiftUI

/// Which direction the bubble grows from during the entrance animation.
/// Picked by the controller based on whether the bubble sits above or below
/// the input — the edge closest to the input stays fixed so the bubble always
/// animates AWAY from the input (never briefly covers it).
enum BubbleGrowthAnchor {
    case fromBottom   // bubble sits above input → bottom edge fixed, grows up
    case fromTop      // bubble sits below input → top edge fixed, grows down

    var unitPoint: UnitPoint {
        switch self {
        case .fromBottom: return .bottom
        case .fromTop:    return .top
        }
    }

    /// Offset applied to the invisible state — the bubble drifts TOWARD the
    /// input from this offset when entering, and back OUT in the opposite
    /// direction when leaving. Small value (~6pt) so the motion reads as a
    /// gentle drift, not a slide.
    var entryOffset: CGSize {
        switch self {
        case .fromBottom: return CGSize(width: 0, height: -6)  // above input: drifts down into place
        case .fromTop:    return CGSize(width: 0, height: 6)   // below input: drifts up into place
        }
    }
}

/// Observable state for the inline action bubble.
/// The controller mutates this; the view reacts via `@ObservedObject`.
/// Using a state object (instead of replacing the hosting view's rootView)
/// lets SwiftUI animate both the entrance AND the exit transitions.
@MainActor
final class BubbleState: ObservableObject {
    @Published var visible: Bool = false
    @Published var action: String = ""
    @Published var anchor: BubbleGrowthAnchor = .fromBottom
    var onFill: () -> Void = {}
    var onClose: () -> Void = {}
}

/// Inline action bubble — compact, glassy, and animated with a soft
/// "drift in / drift out" motion driven by `BubbleState.visible`.
///
/// Implementation note: content is always in the layout tree (no `if`
/// conditional). Visibility is driven entirely by visual modifiers
/// (opacity / scale / offset / blur). This keeps `fittingSize` stable at
/// all times so the hosting panel can be sized correctly even before the
/// entrance animation runs.
struct BubbleView: View {
    @ObservedObject var state: BubbleState

    var body: some View {
        content
            .opacity(state.visible ? 1 : 0)
            .scaleEffect(state.visible ? 1 : 0.86, anchor: state.anchor.unitPoint)
            .offset(state.visible ? .zero : state.anchor.entryOffset)
            .blur(radius: state.visible ? 0 : 5)
            .animation(.spring(response: 0.5, dampingFraction: 0.82), value: state.visible)
    }

    // MARK: - Content

    private var content: some View {
        HStack(alignment: .top, spacing: 6) {
            Text(state.action)
                .font(.system(size: 11))
                .lineSpacing(1)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 200, alignment: .leading)
                .textSelection(.enabled)
                .foregroundStyle(.primary.opacity(0.92))

            Spacer(minLength: 0)

            VStack(spacing: 3) {
                Button(action: state.onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 13, height: 13)
                }
                .buttonStyle(.plain)
                .help("关闭")

                Button(action: state.onFill) {
                    Text("填入")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor)
                        .clipShape(.capsule)
                }
                .buttonStyle(.plain)
                .help("把 action 填入当前输入框")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .modifier(GlassOrMaterial(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.white.opacity(0.14), lineWidth: 0.5)
        )
    }

}
