// FloartTests/ContextStoreTests.swift
import XCTest
@testable import Floart

final class ContextStoreTests: XCTestCase {

    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ContextStoreTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    // MARK: - File layout

    func testAppWriteCreatesAppMd() {
        let store = ContextStore(rootDir: tempDir)
        store.append(
            appName: "VS Code",
            bundleId: "com.microsoft.VSCode",
            scene: .vibeCoding,
            chatTitle: nil,
            advice: "first advice",
            contextKey: "app:com.microsoft.VSCode"
        )
        let file = tempDir.appendingPathComponent("VS Code/app.md")
        XCTAssertTrue(FileManager.default.fileExists(atPath: file.path))
    }

    func testChatWriteCreatesTitledFile() {
        let store = ContextStore(rootDir: tempDir)
        store.append(
            appName: "微信",
            bundleId: "com.tencent.xinWeChat",
            scene: .dmChat,
            chatTitle: "Ceciliax",
            advice: "first advice",
            contextKey: "chat:微信:Ceciliax"
        )
        let file = tempDir.appendingPathComponent("微信/Ceciliax.md")
        XCTAssertTrue(FileManager.default.fileExists(atPath: file.path))
    }

    func testSanitizesSpecialCharsInPath() {
        let store = ContextStore(rootDir: tempDir)
        store.append(
            appName: "Some/App",
            bundleId: "test",
            scene: .dmChat,
            chatTitle: "user:name",
            advice: "x",
            contextKey: "chat:Some/App:user:name"
        )
        // Path-unsafe chars replaced with "_".
        let file = tempDir.appendingPathComponent("Some_App/user_name.md")
        XCTAssertTrue(FileManager.default.fileExists(atPath: file.path))
    }

    // MARK: - History semantics

    func testHistoryPrependsNewestFirst() {
        let store = ContextStore(rootDir: tempDir)
        store.append(
            appName: "App", bundleId: "b", scene: .note, chatTitle: nil,
            advice: "older advice", contextKey: "app:b"
        )
        // sleep not needed; the timestamp format includes seconds but we
        // only care about ORDER in the file, which the struct controls.
        store.append(
            appName: "App", bundleId: "b", scene: .note, chatTitle: nil,
            advice: "newer advice", contextKey: "app:b"
        )

        let file = tempDir.appendingPathComponent("App/app.md")
        let content = try! String(contentsOf: file, encoding: .utf8)
        let newerIdx = content.range(of: "newer advice")!.lowerBound
        let olderIdx = content.range(of: "older advice")!.lowerBound
        XCTAssertLessThan(newerIdx, olderIdx, "newest entry should be above older entries")
    }

    func testReadReturnsMostRecentHistoryEntry() {
        let store = ContextStore(rootDir: tempDir)
        store.append(
            appName: "App", bundleId: "b", scene: .note, chatTitle: nil,
            advice: "first", contextKey: "app:b"
        )
        store.append(
            appName: "App", bundleId: "b", scene: .note, chatTitle: nil,
            advice: "second", contextKey: "app:b"
        )
        store.append(
            appName: "App", bundleId: "b", scene: .note, chatTitle: nil,
            advice: "third", contextKey: "app:b"
        )
        let bucket = store.read(appName: "App", bundleId: "b", scene: .note, chatTitle: nil)
        XCTAssertNotNil(bucket)
        XCTAssertEqual(bucket?.lastAdvice, "third")
    }

    // MARK: - Notes preservation

    func testNotesSectionPreservedAcrossAppends() {
        let store = ContextStore(rootDir: tempDir)
        store.append(
            appName: "App", bundleId: "b", scene: .note, chatTitle: nil,
            advice: "advice 1", contextKey: "app:b"
        )

        // User manually edits the Notes section.
        let file = tempDir.appendingPathComponent("App/app.md")
        var content = try! String(contentsOf: file, encoding: .utf8)
        content = content.replacingOccurrences(
            of: "## Notes\n\n_(edit freely — this section gets injected into the analysis prompt for this bucket)_",
            with: "## Notes\n\nCeciliax is a designer. Use formal tone."
        )
        try! content.write(to: file, atomically: true, encoding: .utf8)

        // Floart writes a new history entry.
        store.append(
            appName: "App", bundleId: "b", scene: .note, chatTitle: nil,
            advice: "advice 2", contextKey: "app:b"
        )

        let bucket = store.read(appName: "App", bundleId: "b", scene: .note, chatTitle: nil)
        XCTAssertEqual(bucket?.notes, "Ceciliax is a designer. Use formal tone.")
        XCTAssertEqual(bucket?.lastAdvice, "advice 2")
    }

    func testEmptyNotesReadsAsEmpty() {
        let store = ContextStore(rootDir: tempDir)
        store.append(
            appName: "App", bundleId: "b", scene: .note, chatTitle: nil,
            advice: "advice", contextKey: "app:b"
        )
        let bucket = store.read(appName: "App", bundleId: "b", scene: .note, chatTitle: nil)
        // Placeholder text is stripped, so user-empty Notes → "".
        XCTAssertEqual(bucket?.notes, "")
    }

    // MARK: - Missing file

    func testReadingMissingBucketReturnsNil() {
        let store = ContextStore(rootDir: tempDir)
        let bucket = store.read(appName: "Nothing", bundleId: "x", scene: .note, chatTitle: nil)
        XCTAssertNil(bucket)
    }
}
