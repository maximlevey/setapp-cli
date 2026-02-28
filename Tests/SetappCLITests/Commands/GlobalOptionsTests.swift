@testable import SetappCLI
import XCTest

final class GlobalOptionsTests: XCTestCase {
    // MARK: - Lifecycle

    override func tearDown() {
        Printer.isVerbose = false
        Printer.isDebug = false
        super.tearDown()
    }

    // MARK: - Parsing

    func testDefaultsAreFalse() throws {
        let options = try GlobalOptions.parse([])
        XCTAssertFalse(options.verbose)
        XCTAssertFalse(options.debug)
    }

    func testVerboseShortFlag() throws {
        let options = try GlobalOptions.parse(["-v"])
        XCTAssertTrue(options.verbose)
    }

    func testVerboseLongFlag() throws {
        let options = try GlobalOptions.parse(["--verbose"])
        XCTAssertTrue(options.verbose)
    }

    func testDebugShortFlag() throws {
        let options = try GlobalOptions.parse(["-d"])
        XCTAssertTrue(options.debug)
    }

    func testDebugLongFlag() throws {
        let options = try GlobalOptions.parse(["--debug"])
        XCTAssertTrue(options.debug)
    }

    func testBothFlagsTogether() throws {
        let options = try GlobalOptions.parse(["-v", "-d"])
        XCTAssertTrue(options.verbose)
        XCTAssertTrue(options.debug)
    }

    // MARK: - Apply

    func testApplySetsVerboseOnPrinter() throws {
        let options = try GlobalOptions.parse(["--verbose"])
        options.apply()
        XCTAssertTrue(Printer.isVerbose)
        XCTAssertFalse(Printer.isDebug)
    }

    func testApplySetsDebugOnPrinter() throws {
        let options = try GlobalOptions.parse(["--debug"])
        options.apply()
        XCTAssertFalse(Printer.isVerbose)
        XCTAssertTrue(Printer.isDebug)
    }

    func testApplySetsBothOnPrinter() throws {
        let options = try GlobalOptions.parse(["-v", "-d"])
        options.apply()
        XCTAssertTrue(Printer.isVerbose)
        XCTAssertTrue(Printer.isDebug)
    }

    func testApplyDefaultLeavesDisabled() throws {
        Printer.isVerbose = true
        Printer.isDebug = true
        let options = try GlobalOptions.parse([])
        options.apply()
        XCTAssertFalse(Printer.isVerbose)
        XCTAssertFalse(Printer.isDebug)
    }

    // MARK: - Environment Variable

    func testSetappDebugEnvVarEnablesDebug() throws {
        setenv("SETAPP_DEBUG", "1", 1)
        defer { unsetenv("SETAPP_DEBUG") }

        let options = try GlobalOptions.parse([])
        options.apply()
        XCTAssertTrue(Printer.isDebug, "SETAPP_DEBUG=1 should enable debug mode")
    }

    func testSetappDebugEnvVarIgnoredWhenNotOne() throws {
        setenv("SETAPP_DEBUG", "0", 1)
        defer { unsetenv("SETAPP_DEBUG") }

        let options = try GlobalOptions.parse([])
        options.apply()
        XCTAssertFalse(Printer.isDebug, "SETAPP_DEBUG=0 should not enable debug mode")
    }
}
