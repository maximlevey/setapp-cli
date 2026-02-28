import Foundation

enum SetappError: LocalizedError, CustomStringConvertible, Equatable {
    case appNotFound(name: String)
    case appNotInstalled(name: String)
    case appAlreadyInstalled(name: String)
    case databaseNotFound(path: String)
    case databaseQueryFailed(message: String)
    case bundleFileNotFound(path: String)
    case bundleFileEmpty
    case xpcConnectionFailed(message: String)
    case xpcRequestTimedOut(seconds: Int)
    case xpcRequestFailed(message: String)
    case frameworkLoadFailed(message: String)
    case setappAppsDirectoryNotFound(path: String)
    case installFailed(app: String, message: String)
    case uninstallFailed(app: String, message: String)
    case generalError(message: String)

    var description: String {
        switch self {
        case let .appNotFound(name):
            "\(name): no matching app in Setapp catalogue"
        case let .appNotInstalled(name):
            "\(name) is not installed via Setapp"
        case let .appAlreadyInstalled(name):
            "\(name) is already installed"
        case let .databaseNotFound(path):
            "Setapp database not found: \(path)\nIs Setapp installed?"
        case let .databaseQueryFailed(message):
            "database query failed: \(message)"
        case let .bundleFileNotFound(path):
            "no such file: \(path)"
        case .bundleFileEmpty:
            "bundle file is empty"
        case let .xpcConnectionFailed(message):
            "XPC connection failed: \(message)\nIs Setapp running?"
        case let .xpcRequestTimedOut(seconds):
            "XPC request timed out after \(seconds)s"
        case let .xpcRequestFailed(message):
            "XPC request failed: \(message)"
        case let .frameworkLoadFailed(message):
            "cannot load SetappInterface: \(message)"
        case let .setappAppsDirectoryNotFound(path):
            "Setapp apps directory not found: \(path)"
        case let .installFailed(app, message):
            "\(app): \(message)"
        case let .uninstallFailed(app, message):
            "\(app): \(message)"
        case let .generalError(message):
            message
        }
    }

    var errorDescription: String? {
        description
    }
}
