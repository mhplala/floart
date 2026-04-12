// FloartTests/BubbleLayoutTests.swift
//
// Tests for `BubbleController.computeLayout(size:axRect:visibleFrame:
// primaryScreenHeight:gap:)` — the pure positioning logic. AX uses
// top-left-origin global coords; AppKit uses bottom-left-origin. The
// function has to flip correctly, pick "above" vs "below", clamp to
// screen, and keep its growth anchor pointing away from the input so
// the entrance animation doesn't briefly cover the input.
import XCTest
import AppKit
@testable import Floart

final class BubbleLayoutTests: XCTestCase {

    /// Simulated 1440×900 single monitor at origin.
    private let screen = NSRect(x: 0, y: 0, width: 1440, height: 900)
    private let visible = NSRect(x: 0, y: 0, width: 1440, height: 876)  // menu bar at top
    private let primaryH: CGFloat = 900
    private let bubble = NSSize(width: 220, height: 70)
    private let gap: CGFloat = 10

    /// Helper: call the pure layout function with this test's fixed geometry.
    private func layout(axRect: CGRect) -> (CGPoint, BubbleGrowthAnchor) {
        BubbleController.computeLayout(
            size: bubble,
            axRect: axRect,
            visibleFrame: visible,
            primaryScreenHeight: primaryH,
            gap: gap
        )
    }

    // MARK: - Above input placement (enough room above)

    func testInputInMiddleOfScreenPlacesBubbleAbove() {
        // Input at AX (300, 400, 600, 40) — middle of a 1440x900 screen.
        // Plenty of room above (AX y=400 means 400px from top in AX; in
        // AppKit that's 500px from bottom — lots of space up).
        let axInput = CGRect(x: 300, y: 400, width: 600, height: 40)
        let (origin, anchor) = layout(axRect: axInput)

        // "Above" means grow-from-bottom (bottom edge stays fixed so the
        // scale animation doesn't scale into the input).
        XCTAssertEqual(anchor, .fromBottom)

        // Input top edge in AppKit coords: primaryH - axY = 900 - 400 = 500
        // Bubble origin y (bottom-left) should sit gap=10 above that = 510
        XCTAssertEqual(origin.y, 510, accuracy: 0.5)
        // X anchored to input left
        XCTAssertEqual(origin.x, 300, accuracy: 0.5)
    }

    func testBubbleNeverCoversInputWhenPlacedAbove() {
        // Regression: earlier code positioned the bubble so its bottom was
        // level with the input top, then the scale animation briefly
        // overlapped. With gap=10 and anchor=.fromBottom, bubble bottom
        // must be strictly ABOVE input top.
        let axInput = CGRect(x: 100, y: 500, width: 400, height: 30)
        let (origin, _) = layout(axRect: axInput)

        let inputTopY = primaryH - axInput.origin.y  // 400
        XCTAssertGreaterThan(origin.y, inputTopY,
            "bubble bottom (\(origin.y)) must be above input top (\(inputTopY))")
    }

    // MARK: - Below input placement (not enough room above)

    func testInputNearTopOfScreenPlacesBubbleBelow() {
        // Input near top: AX (100, 20, 400, 30). Space above = 20, not
        // enough for a 70pt bubble + gap. Must fall back to below.
        let axInput = CGRect(x: 100, y: 20, width: 400, height: 30)
        let (origin, anchor) = layout(axRect: axInput)

        XCTAssertEqual(anchor, .fromTop)

        // Input bottom edge in AppKit: primaryH - axY - axH = 900-20-30 = 850
        // Bubble origin y should be at input bottom - bubbleHeight - gap
        // = 850 - 70 - 10 = 770
        XCTAssertEqual(origin.y, 770, accuracy: 0.5)
    }

    func testBelowBubbleIsStrictlyBelowInput() {
        let axInput = CGRect(x: 100, y: 10, width: 400, height: 30)
        let (origin, _) = layout(axRect: axInput)

        let inputBottomY = primaryH - axInput.origin.y - axInput.size.height
        let bubbleTop = origin.y + bubble.height
        XCTAssertLessThan(bubbleTop, inputBottomY,
            "bubble top (\(bubbleTop)) must be below input bottom (\(inputBottomY))")
    }

    // MARK: - X clamping

    func testBubbleXClampedToVisibleFrameRight() {
        // Input flush against right edge — bubble would extend off-screen
        // to the right. Must clamp so bubble right edge stays inside.
        let axInput = CGRect(x: 1380, y: 400, width: 50, height: 30)
        let (origin, _) = layout(axRect: axInput)

        XCTAssertLessThanOrEqual(origin.x + bubble.width, visible.maxX,
            "bubble must stay within the visible frame's right edge")
    }

    func testBubbleXClampedToVisibleFrameLeft() {
        // Input with negative AX x — bubble should clamp to visible minX.
        let axInput = CGRect(x: -20, y: 400, width: 200, height: 30)
        let (origin, _) = layout(axRect: axInput)

        XCTAssertGreaterThanOrEqual(origin.x, visible.minX)
    }

    // MARK: - Growth anchor invariant

    func testGrowthAnchorAlwaysPointsAwayFromInput() {
        // Any input with room above → anchor.fromBottom (bubble extends up,
        // away from the input).
        let midInput = CGRect(x: 500, y: 500, width: 400, height: 40)
        let (_, midAnchor) = layout(axRect: midInput)
        XCTAssertEqual(midAnchor, .fromBottom)

        // Input too close to top → anchor.fromTop (bubble extends down,
        // away from the input).
        let topInput = CGRect(x: 500, y: 5, width: 400, height: 40)
        let (_, topAnchor) = layout(axRect: topInput)
        XCTAssertEqual(topAnchor, .fromTop)
    }

    // MARK: - Multi-screen sanity

    func testSecondaryScreenCoordSpace() {
        // Imagine a second screen to the right at x=1440, 1920x1080.
        // A focused input on the secondary screen has AX x=2400, y=300.
        // With the secondary screen's visibleFrame, the layout should
        // honor that frame's maxX for right-clamping.
        let secondaryVisible = NSRect(x: 1440, y: 0, width: 1920, height: 1056)

        let axInput = CGRect(x: 2400, y: 300, width: 600, height: 40)
        let (origin, anchor) = BubbleController.computeLayout(
            size: bubble,
            axRect: axInput,
            visibleFrame: secondaryVisible,
            primaryScreenHeight: primaryH,
            gap: gap
        )

        XCTAssertEqual(anchor, .fromBottom)
        // Input is on the secondary screen; bubble x should be inside it
        XCTAssertGreaterThanOrEqual(origin.x, secondaryVisible.minX)
        XCTAssertLessThanOrEqual(origin.x + bubble.width, secondaryVisible.maxX)
    }
}
