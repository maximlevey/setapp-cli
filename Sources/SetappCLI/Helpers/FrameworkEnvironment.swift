// this_file: Sources/SetappCLI/Helpers/FrameworkEnvironment.swift
import Darwin
import Foundation

/// Configures dyld for the current user's Setapp installation before running commands.
enum FrameworkEnvironment {
    /// Return only search-path values that need changing, preserving existing entries.
    static func environmentUpdates(directory: String, environment: [String: String]) -> [String: String] {
        var updates: [String: String] = [:]
        for key: String in ["DYLD_FALLBACK_FRAMEWORK_PATH", "DYLD_FALLBACK_LIBRARY_PATH"] {
            let existing: [String] = (environment[key] ?? "").split(separator: ":").map(String.init)
            let value: String = ([directory] + existing.filter { $0 != directory }).joined(separator: ":")
            if environment[key] != value {
                updates[key] = value
            }
        }
        return updates
    }

    /// Relaunch once with Setapp's framework and dylib paths available at process startup.
    ///
    /// dyld reads these variables at startup, so setenv alone cannot fix dlopen.
    /// This must run before any command has installed or removed an app.
    static func prepare(frameworkPath: String) throws {
        let path: String = NSString(string: frameworkPath).expandingTildeInPath
        guard FileManager.default.fileExists(atPath: path) else {
            return
        }
        let directory: String = URL(fileURLWithPath: path).deletingLastPathComponent().deletingLastPathComponent().path
        let updates: [String: String] = environmentUpdates(directory: directory, environment: ProcessInfo.processInfo.environment)
        guard !updates.isEmpty else {
            return
        }
        guard let executable: URL = Bundle.main.executableURL else {
            throw SetappError.generalError(message: "Cannot locate the executable to configure Setapp's framework paths")
        }
        for (key, value) in updates {
            guard setenv(key, value, 1) == 0 else {
                throw SetappError.generalError(message: "Cannot set \(key): \(String(cString: strerror(errno)))")
            }
        }
        execv(executable.path, CommandLine.unsafeArgv)
        throw SetappError.generalError(message: "Cannot restart with Setapp's framework paths: \(String(cString: strerror(errno)))")
    }
}
