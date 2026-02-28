import Foundation

/// Dependency container for injectable services.
///
/// Commands use this container to access dependencies, allowing tests
/// to substitute mock implementations.
enum Dependencies {
    /// App catalogue lookup.
    static var lookup: AppLookup = LiveDatabase()

    /// App install/uninstall service.
    static var installer: AppInstaller = LiveInstaller()

    /// App installation detector.
    static var detector: AppDetecting = LiveDetector()

    /// Environment readiness check. Replaced with a no-op in tests.
    static var verifyEnvironment: () throws -> Void = SetappEnvironment.verify

    /// Reset all dependencies to their live defaults.
    static func reset() {
        lookup = LiveDatabase()
        installer = LiveInstaller()
        detector = LiveDetector()
        verifyEnvironment = SetappEnvironment.verify
    }
}
