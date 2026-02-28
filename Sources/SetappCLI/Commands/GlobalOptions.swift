import ArgumentParser
import Foundation

struct GlobalOptions: ParsableArguments {
    @Flag(name: .shortAndLong, help: "Enable verbose output.")
    var verbose = false

    @Flag(name: .shortAndLong, help: "Enable debug output (or set SETAPP_DEBUG=1).")
    var debug = false

    /// Apply these flags to the global Printer state.
    func apply() {
        Printer.isVerbose = verbose
        Printer.isDebug = debug || ProcessInfo.processInfo.environment["SETAPP_DEBUG"] == "1"
    }
}
