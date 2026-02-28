import Foundation

enum Printer {
    static var isVerbose = false
    static var isDebug = false

    /// Whether stdout is a terminal (enables color output).
    private static let isTTY = isatty(STDOUT_FILENO) != 0

    // ANSI escape codes
    private static let bold = isTTY ? "\u{1B}[1m" : ""
    private static let boldBlue = isTTY ? "\u{1B}[1;34m" : ""
    private static let yellow = isTTY ? "\u{1B}[33m" : ""
    private static let red = isTTY ? "\u{1B}[31m" : ""
    private static let reset = isTTY ? "\u{1B}[0m" : ""

    /// Section header — bold blue "==>" followed by bold text.
    /// Use for announcing a major action (e.g. "==> Installing Proxyman").
    static func info(_ message: String) {
        print("\(boldBlue)==>\(reset) \(bold)\(message)\(reset)")
    }

    /// Plain text output.
    static func log(_ message: String) {
        print(message)
    }

    /// Warning — yellow "Warning:" prefix.
    static func warning(_ message: String) {
        print("\(yellow)Warning:\(reset) \(message)")
    }

    /// Verbose output — only shown with -v/--verbose.
    static func verbose(_ message: String) {
        guard isVerbose else { return }
        print(message)
    }

    /// Debug output — only shown with -d/--debug, writes to stderr.
    static func debug(_ message: String) {
        guard isDebug else { return }
        FileHandle.standardError.write(Data("[debug] \(message)\n".utf8))
    }

    /// Error — red "Error:" prefix, writes to stderr.
    static func error(_ message: String) {
        let tty = isatty(STDERR_FILENO) != 0
        let errRed = tty ? "\u{1B}[31m" : ""
        let rst = tty ? "\u{1B}[0m" : ""
        FileHandle.standardError.write(Data("\(errRed)Error:\(rst) \(message)\n".utf8))
    }
}
