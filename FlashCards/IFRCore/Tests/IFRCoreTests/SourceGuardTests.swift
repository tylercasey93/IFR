import XCTest
@testable import IFRCore

final class SourceGuardTests: XCTestCase {
    private let testFile = URL(fileURLWithPath: #filePath)
    private let forbiddenImports = ["import UIKit", "import SwiftUI", "import Combine"]
    private let forbiddenSchedulerCalls = [".review(", "CardState("]
    private let workflowMarkers = [
        "ubuntu-latest", "FlashCards/scripts/install-swift-linux.sh", "FlashCards/scripts/test-core.sh",
    ]

    private var sourcesRoot: URL {
        testFile.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sources/IFRCore")
    }

    private var adventureRoot: URL { sourcesRoot.appendingPathComponent("Adventure") }

    private func swiftFiles(under directory: URL) -> [URL] {
        let enumerator = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: nil)
        let files = enumerator?.compactMap { $0 as? URL } ?? []
        return files.filter { $0.pathExtension == "swift" }.sorted { $0.path < $1.path }
    }

    private func repositoryRoot() -> URL? {
        var directory = testFile.deletingLastPathComponent()
        while directory.path != "/" {
            if FileManager.default.fileExists(atPath: directory.appendingPathComponent(".git").path) {
                return directory
            }
            directory = directory.deletingLastPathComponent()
        }
        return nil
    }

    private func assertNoFile(under directory: URL, contains fragments: [String]) throws {
        for file in swiftFiles(under: directory) {
            let text = try String(contentsOf: file, encoding: .utf8)
            for fragment in fragments {
                XCTAssertFalse(text.contains(fragment), "\(file.lastPathComponent) contains \(fragment)")
            }
        }
    }

    private func assertAdventureDirectoryExists() {
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: adventureRoot.path, isDirectory: &isDirectory)
        XCTAssertTrue(exists && isDirectory.boolValue, "Sources/IFRCore/Adventure is missing")
    }

    func testIFRCoreSourcesImportOnlyFoundation() throws {
        XCTAssertFalse(swiftFiles(under: sourcesRoot).isEmpty, "no sources found at \(sourcesRoot.path)")
        try assertNoFile(under: sourcesRoot, contains: forbiddenImports)
    }

    func testAdventureSourcesNeverCallSchedulerReviewOrBuildCardState() throws {
        assertAdventureDirectoryExists()
        try assertNoFile(under: adventureRoot, contains: forbiddenSchedulerCalls)
    }

    func testAdventureSourcesContainNoComments() throws {
        assertAdventureDirectoryExists()
        for file in swiftFiles(under: adventureRoot) {
            let text = try String(contentsOf: file, encoding: .utf8)
            let code = StringLiteralStripper.strip(text)
            XCTAssertFalse(code.contains("//"), "\(file.lastPathComponent) contains a line comment")
            XCTAssertFalse(code.contains("/*"), "\(file.lastPathComponent) contains a block comment")
        }
    }

    func testAdventureSourceFilesOutsideSpritesStayUnderOneHundredFiftyLines() throws {
        assertAdventureDirectoryExists()
        let spriteFragment = "Pixel/Sprites/"
        for file in swiftFiles(under: adventureRoot) where !file.path.contains(spriteFragment) {
            let text = try String(contentsOf: file, encoding: .utf8)
            let lineCount = text.split(separator: "\n", omittingEmptySubsequences: false).count
            XCTAssertLessThanOrEqual(lineCount, 150, file.lastPathComponent)
        }
    }

    func testCoreWorkflowInstallsSwiftThenRunsCoreScript() throws {
        let workflow = try coreWorkflowText()
        let positions = workflowMarkers.map { workflow.range(of: $0)?.lowerBound }
        let found = positions.compactMap { $0 }
        XCTAssertEqual(found.count, workflowMarkers.count, "workflow must name \(workflowMarkers)")
        XCTAssertEqual(found, found.sorted(), "install must come before the test script")
    }

    func testCoreWorkflowRunsOnPushAndPullRequest() throws {
        let workflow = try coreWorkflowText()
        XCTAssertTrue(workflow.contains("push"))
        XCTAssertTrue(workflow.contains("pull_request"))
    }

    private func coreWorkflowText() throws -> String {
        let root = try XCTUnwrap(repositoryRoot(), "no .git above \(testFile.path)")
        let workflow = root.appendingPathComponent(".github/workflows/core-tests.yml")
        return try String(contentsOf: workflow, encoding: .utf8)
    }
}
