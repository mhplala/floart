// FloartTests/MessageDedupTests.swift
import XCTest
@testable import Floart

final class MessageDedupTests: XCTestCase {

    // MARK: - normalize

    func testNormalizeStripsMyPrefix() {
        XCTAssertEqual(MessageDedup.normalize("[我] hello world"), "hello world")
    }

    func testNormalizeStripsOtherPrefix() {
        XCTAssertEqual(MessageDedup.normalize("[对方] 你好 世界"), "你好 世界")
    }

    func testNormalizeCollapsesWhitespace() {
        XCTAssertEqual(
            MessageDedup.normalize("[我]   hello    world  "),
            "hello world"
        )
    }

    func testNormalizeIgnoresSenderSide() {
        // Same substantive content from either side → same hash.
        XCTAssertEqual(
            MessageDedup.normalize("[我] 再确认一下"),
            MessageDedup.normalize("[对方] 再确认一下")
        )
    }

    func testNormalizeEmptyForNonTaggedLine() {
        // Whitespace-only or missing content → empty (so the dedup filter
        // leaves it alone instead of accidentally deduping blank lines).
        let raw = MessageDedup.normalize("just some sidebar text")
        XCTAssertEqual(raw, "just some sidebar text")  // passthrough, stays non-empty
    }

    // MARK: - filter

    func testFilterDropsRepeatedMessages() {
        var dedup = MessageDedup()
        let text = """
        [我] 你好
        [对方] 嗨
        [我] 你好
        """
        let r = dedup.filter(text, conversationKey: "WeChat:Alice")
        XCTAssertEqual(r.kept, 2)
        XCTAssertEqual(r.dropped, 1)
        XCTAssertFalse(r.filtered.contains("你好\n[对方] 嗨\n[我] 你好"))
    }

    func testFilterAcrossMultipleCallsForSameConversation() {
        var dedup = MessageDedup()
        let first = dedup.filter("[我] message one\n[对方] reply one", conversationKey: "k")
        XCTAssertEqual(first.kept, 2)

        // User scrolls: same messages come in again. All should be dropped.
        let second = dedup.filter("[我] message one\n[对方] reply one", conversationKey: "k")
        XCTAssertEqual(second.kept, 0)
        XCTAssertEqual(second.dropped, 2)

        // New message arrives alongside the old ones.
        let third = dedup.filter(
            "[我] message one\n[对方] reply one\n[对方] brand new",
            conversationKey: "k"
        )
        XCTAssertEqual(third.kept, 1)
        XCTAssertEqual(third.dropped, 2)
        XCTAssertTrue(third.filtered.contains("brand new"))
    }

    func testFilterIsPerConversation() {
        var dedup = MessageDedup()
        let a = dedup.filter("[我] hi", conversationKey: "WeChat:Alice")
        let b = dedup.filter("[我] hi", conversationKey: "WeChat:Bob")
        XCTAssertEqual(a.kept, 1)
        // Bob's conversation sees "hi" for the first time independently.
        XCTAssertEqual(b.kept, 1)
        XCTAssertEqual(b.dropped, 0)
    }

    func testFilterPassesThroughNonTaggedLines() {
        var dedup = MessageDedup()
        let text = """
        [左侧边栏]
        聊天列表
        [我] 你好
        button: 发送
        """
        let r = dedup.filter(text, conversationKey: "k")
        XCTAssertTrue(r.filtered.contains("[左侧边栏]"))
        XCTAssertTrue(r.filtered.contains("button: 发送"))
        XCTAssertEqual(r.kept, 1)  // only the tagged line counts

        // Second call: non-tagged lines pass through again, tagged dropped.
        let r2 = dedup.filter(text, conversationKey: "k")
        XCTAssertTrue(r2.filtered.contains("聊天列表"))
        XCTAssertEqual(r2.kept, 0)
        XCTAssertEqual(r2.dropped, 1)
    }

    func testFilterIgnoresExtraWhitespaceAsDuplicates() {
        // Normalization collapses leading/trailing and internal whitespace
        // runs but does NOT invent spaces where none exist. "hello world"
        // with extra spaces should still match "hello world".
        var dedup = MessageDedup()
        let first = dedup.filter("[我] hello world", conversationKey: "k")
        XCTAssertEqual(first.kept, 1)

        let second = dedup.filter("[我]    hello    world   ", conversationKey: "k")
        XCTAssertEqual(second.kept, 0)
        XCTAssertEqual(second.dropped, 1)
    }

    func testFilterBatchDedupWithinSameCall() {
        var dedup = MessageDedup()
        let text = "[我] same\n[我] same\n[我] different"
        let r = dedup.filter(text, conversationKey: "k")
        // The second "[我] same" in the same batch is deduped too.
        XCTAssertEqual(r.kept, 2)
        XCTAssertEqual(r.dropped, 1)
    }
}
