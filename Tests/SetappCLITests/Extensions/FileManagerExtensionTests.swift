@testable import SetappCLI
import XCTest

final class FileManagerExtensionTests: XCTestCase {
    func testDirectoryExistsForRealDirectory() {
        let tmp = TempDirectory()
        XCTAssertTrue(FileManager.default.directoryExists(at: tmp.url.path))
    }

    func testDirectoryExistsReturnsFalseForFile() {
        let tmp = TempDirectory()
        let file = tmp.createFile(named: "test.txt", content: "hello")
        XCTAssertFalse(FileManager.default.directoryExists(at: file.path))
    }

    func testDirectoryExistsReturnsFalseForNonExistent() {
        XCTAssertFalse(
            FileManager.default.directoryExists(at: "/nonexistent_path_\(UUID().uuidString)")
        )
    }
}
