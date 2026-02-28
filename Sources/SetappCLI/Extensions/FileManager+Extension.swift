import Foundation

extension FileManager {
    /// Check if a directory exists at the given path.
    func directoryExists(at path: String) -> Bool {
        var isDir: ObjCBool = false
        return fileExists(atPath: path, isDirectory: &isDir) && isDir.boolValue
    }
}
