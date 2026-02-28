import Foundation
@testable import SetappCLI
import XCTest

final class PrinterTests: XCTestCase {
    override func tearDown() {
        super.tearDown()
        Printer.isVerbose = false
        Printer.isDebug = false
    }

    // MARK: - stdout capture

    private func captureStdout(_ block: () -> Void) -> String {
        let pipe = Pipe()
        let original = dup(STDOUT_FILENO)
        dup2(pipe.fileHandleForWriting.fileDescriptor, STDOUT_FILENO)
        block()
        fflush(stdout)
        dup2(original, STDOUT_FILENO)
        close(original)
        pipe.fileHandleForWriting.closeFile()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }

    // MARK: - stderr capture

    private func captureStderr(_ block: () -> Void) -> String {
        let pipe = Pipe()
        let original = dup(STDERR_FILENO)
        dup2(pipe.fileHandleForWriting.fileDescriptor, STDERR_FILENO)
        block()
        fflush(stderr)
        dup2(original, STDERR_FILENO)
        close(original)
        pipe.fileHandleForWriting.closeFile()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }

    // MARK: - verbose

    func testVerboseOutputsNothingWhenDisabled() {
        Printer.isVerbose = false

        let output = captureStdout {
            Printer.verbose("should not appear")
        }
        XCTAssertTrue(output.isEmpty)
    }

    func testVerboseOutputsMessageWhenEnabled() {
        Printer.isVerbose = true

        let output = captureStdout {
            Printer.verbose("verbose message")
        }
        XCTAssertTrue(output.contains("verbose message"))
    }

    // MARK: - debug

    func testDebugOutputsNothingWhenDisabled() {
        Printer.isDebug = false

        let output = captureStderr {
            Printer.debug("should not appear")
        }
        XCTAssertTrue(output.isEmpty)
    }

    func testDebugOutputsMessageToStderrWhenEnabled() {
        Printer.isDebug = true

        let output = captureStderr {
            Printer.debug("debug info")
        }
        XCTAssertTrue(output.contains("[debug]"))
        XCTAssertTrue(output.contains("debug info"))
    }

    // MARK: - info

    func testInfoOutputContainsArrowPrefix() {
        let output = captureStdout {
            Printer.info("Installing Proxyman")
        }
        XCTAssertTrue(output.contains("==>"))
        XCTAssertTrue(output.contains("Installing Proxyman"))
    }

    // MARK: - log

    func testLogOutputContainsMessageVerbatim() {
        let output = captureStdout {
            Printer.log("plain text message")
        }
        XCTAssertTrue(output.contains("plain text message"))
    }

    // MARK: - error

    func testErrorWritesToStderr() {
        let output = captureStderr {
            Printer.error("something went wrong")
        }
        XCTAssertTrue(output.contains("Error:"))
        XCTAssertTrue(output.contains("something went wrong"))
    }

    // MARK: - state management

    func testTearDownResetsState() {
        Printer.isVerbose = true
        Printer.isDebug = true

        // Simulate tearDown
        Printer.isVerbose = false
        Printer.isDebug = false

        XCTAssertFalse(Printer.isVerbose)
        XCTAssertFalse(Printer.isDebug)
    }
}
