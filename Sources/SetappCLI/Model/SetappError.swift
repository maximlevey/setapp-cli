import Foundation

enum SetappError: LocalizedError, CustomStringConvertible {
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
        case .appNotFound(let name):
            return "\(name): no matching app in Setapp catalogue"
        case .appNotInstalled(let name):
            return "\(name) is not installed via Setapp"
        case .appAlreadyInstalled(let name):
            return "\(name) is already installed"
        case .databaseNotFound(let path):
            return "Setapp database not found: \(path)\nIs Setapp installed?"
        case .databaseQueryFailed(let message):
            return "database query failed: \(message)"
        case .bundleFileNotFound(let path):
            return "no such file: \(path)"
        case .bundleFileEmpty:
            return "bundle file is empty"
        case .xpcConnectionFailed(let message):
            return "XPC connection failed: \(message)\nIs Setapp running?"
        case .xpcRequestTimedOut(let seconds):
            return "XPC request timed out after \(seconds)s"
        case .xpcRequestFailed(let message):
            return "XPC request failed: \(message)"
        case .frameworkLoadFailed(let message):
            return "cannot load SetappInterface: \(message)"
        case .setappAppsDirectoryNotFound(let path):
            return "Setapp apps directory not found: \(path)"
        case .installFailed(let app, let message):
            return "\(app): \(message)"
        case .uninstallFailed(let app, let message):
            return "\(app): \(message)"
        case .generalError(let message):
            return message
        }
    }

    var errorDescription: String? { description }
}
