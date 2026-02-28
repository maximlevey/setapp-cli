import Foundation

/// Verifies that Setapp is installed and the user is logged in.
enum SetappEnvironment {
    /// Candidate paths where Setapp.app may be installed.
    private static let setappAppPaths: [URL] = [
        URL(fileURLWithPath: "/Applications/Setapp.app"),
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Applications/Setapp.app")
    ]

    /// Throws a descriptive error if Setapp is not installed or the user is not logged in.
    static func verify() throws {
        guard
            setappAppPaths.contains(where: {
                FileManager.default.fileExists(atPath: $0.path)
            }) else {
            throw SetappError.generalError(
                message: "Setapp is not installed. Download it at setapp.com."
            )
        }

        guard FileManager.default.fileExists(atPath: URL.setappDatabase.path) else {
            throw SetappError.generalError(
                message: "Setapp is installed but you are not logged in." +
                    " Open Setapp and sign in to continue."
            )
        }
    }
}
