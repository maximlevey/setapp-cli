import Foundation

/// Formatted terminal output helper.
enum Printer {
    /// Whether verbose output is enabled.
    static var isVerbose: Bool = false
    /// Whether debug output is enabled.
    static var isDebug: Bool = false

    /// Whether stdout is a terminal (enables color output).
    private static let isTTY: Bool = isatty(STDOUT_FILENO) != 0

    /// ANSI bold escape sequence.
    private static let bold: String = isTTY ? "\u{1B}[1m" : ""
    /// ANSI bold blue escape sequence.
    private static let boldBlue: String = isTTY ? "\u{1B}[1;34m" : ""
    /// ANSI yellow escape sequence.
    private static let yellow: String = isTTY ? "\u{1B}[33m" : ""
    /// ANSI red escape sequence.
    private static let red: String = isTTY ? "\u{1B}[31m" : ""
    /// ANSI reset escape sequence.
    private static let reset: String = isTTY ? "\u{1B}[0m" : ""

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
        guard isVerbose else {
            return
        }
        print(message)
    }

    /// Debug output — only shown with -d/--debug, writes to stderr.
    static func debug(_ message: String) {
        guard isDebug else {
            return
        }
        FileHandle.standardError.write(Data("[debug] \(message)\n".utf8))
    }

    /// Error — red "Error:" prefix, writes to stderr.
    static func error(_ message: String) {
        let tty: Bool = isatty(STDERR_FILENO) != 0
        let errRed: String = tty ? "\u{1B}[31m" : ""
        let rst: String = tty ? "\u{1B}[0m" : ""
        FileHandle.standardError.write(Data("\(errRed)Error:\(rst) \(message)\n".utf8))
    }
}
