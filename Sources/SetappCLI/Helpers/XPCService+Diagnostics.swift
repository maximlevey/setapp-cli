import CBridge
import Foundation

// MARK: - Class Discovery

extension XPCService {
    /// Return names of all ObjC classes starting with "AFX".
    ///
    /// Uses raw pointer access to avoid swift_getObjectType crashes on
    /// unrealized metaclasses from complex frameworks.
    static func allAFXClassNames() -> [String] {
        var count: UInt32 = 0
        guard let classList = objc_copyClassList(&count) else {
            return []
        }

        let rawPtr: UnsafeRawPointer = .init(classList)
        let ptrSize: Int = MemoryLayout<UnsafeRawPointer>.size
        var result: [String] = []

        for index in 0 ..< Int(count) {
            let clsRaw: UnsafeRawPointer = rawPtr.load(
                fromByteOffset: index * ptrSize,
                as: UnsafeRawPointer.self
            )
            let cName: UnsafePointer<CChar> = class_getName(unsafeBitCast(clsRaw, to: AnyClass.self))
            if cName[0] == 0x41, cName[1] == 0x46, cName[2] == 0x58 { // "AFX"
                result.append(String(cString: cName))
            }
        }

        free(UnsafeMutableRawPointer(mutating: rawPtr))
        return result
    }

    /// Return all AFX classes as an array, using NSClassFromString for safety.
    static func allAFXClassList() -> [AnyClass] {
        allAFXClassNames().compactMap { NSClassFromString($0) }
    }

    /// Return all AFX classes as an NSSet for XPC interface allowlists.
    static func allAFXClasses() -> NSSet {
        let classes: [AnyClass] = allAFXClassList()
        let set: NSMutableSet = .init(capacity: classes.count)
        for cls in classes {
            set.add(cls)
        }
        guard let result: NSSet = set.copy() as? NSSet else {
            return NSSet()
        }
        return result
    }
}

// MARK: - Diagnostics

extension XPCService {
    /// Run diagnostics and return results as JSON string.
    static func diag() throws -> String {
        var results: [[String: Any]] = []
        let fwPath: String = NSString(string: frameworkPath).expandingTildeInPath
        let fwExists: Bool = FileManager.default.fileExists(atPath: fwPath)

        results.append(diagBundleID())
        results.append(diagFrameworkExists(path: fwPath, exists: fwExists))

        let dlopenOK: (result: [String: Any], ok: Bool) = diagDlopen(path: fwPath, exists: fwExists)
        results.append(dlopenOK.result)

        results.append(diagAFXClasses())
        results.append(diagExpectedSelectors())
        results.append(diagAdaptorProbe(dlopenOK: dlopenOK.ok))
        results.append(diagCrashReports())

        let jsonDict: [String: Any] = ["diag": results]
        let data: Data = try JSONSerialization.data(
            withJSONObject: jsonDict,
            options: [.prettyPrinted, .sortedKeys]
        )
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    /// Check the main bundle identifier and report whether it is present.
    private static func diagBundleID() -> [String: Any] {
        [
            "check": "bundleIdentifier",
            "value": Bundle.main.bundleIdentifier ?? "<nil>",
            "ok": Bundle.main.bundleIdentifier != nil
        ]
    }

    /// Check whether the SetappInterface framework binary exists on disk.
    private static func diagFrameworkExists(path: String, exists: Bool) -> [String: Any] {
        ["check": "frameworkExists", "path": path, "ok": exists]
    }

    /// Attempt to dlopen the framework and report success or the dlerror message.
    private static func diagDlopen(
        path: String, exists: Bool
    ) -> (result: [String: Any], ok: Bool) {
        guard exists else {
            return (["check": "dlopen", "ok": false, "error": "framework binary not found"], false)
        }
        if dlopen(path, RTLD_NOW | RTLD_GLOBAL) != nil {
            return (["check": "dlopen", "ok": true], true)
        }
        let err: String = .init(cString: dlerror())
        return (["check": "dlopen", "ok": false, "error": err], false)
    }

    /// Count how many AFX ObjC classes are available after loading the framework.
    private static func diagAFXClasses() -> [String: Any] {
        let afxClasses: [AnyClass] = allAFXClassList()
        return [
            "check": "afxClassCount",
            "value": afxClasses.count,
            "ok": !afxClasses.isEmpty
        ]
    }

    /// Verify that the expected selectors exist on the apps management client class.
    private static func diagExpectedSelectors() -> [String: Any] {
        let expected: [String] = [
            "installVendorApp:shouldLaunch:callback:",
            "fetchAppsWithCallback:",
            "fetchAppWithID:callback:"
        ]
        var selectorResults: [[String: Any]] = []
        var clientClassFound: Bool = false

        if let clientClass: AnyClass = NSClassFromString(appsClientClass) {
            clientClassFound = true
            let methodNames: [String] = methodNamesForClass(clientClass)
            for sel in expected {
                selectorResults.append(["selector": sel, "found": methodNames.contains(sel)])
            }
        } else {
            for sel in expected {
                selectorResults.append(["selector": sel, "found": false])
            }
        }

        return [
            "check": "expectedSelectors",
            "class": appsClientClass,
            "classFound": clientClassFound,
            "selectors": selectorResults,
            "ok": selectorResults.allSatisfy { ($0["found"] as? Bool) == true }
        ]
    }

    /// List the method names defined on a given ObjC class.
    private static func methodNamesForClass(_ cls: AnyClass) -> [String] {
        var methodCount: UInt32 = 0
        let methods: UnsafeMutablePointer<Method>? = class_copyMethodList(cls, &methodCount)
        var names: [String] = []
        if let methods {
            for index in 0 ..< Int(methodCount) {
                names.append(String(cString: sel_getName(method_getName(methods[index]))))
            }
            free(methods)
        }
        return names
    }

    /// Probe whether the adaptor for the AppsManagement XPC service can be created.
    private static func diagAdaptorProbe(dlopenOK: Bool) -> [String: Any] {
        var result: [String: Any] = [
            "check": "appsManagementAdaptorProbe",
            "service": appsServiceName
        ]

        guard dlopenOK else {
            result["ok"] = false
            result["error"] = "framework not loaded"
            return result
        }

        guard
            let cls: AnyClass = NSClassFromString(appsClientClass),
            let reqRaw: AnyObject = (cls as AnyObject)
                .perform(NSSelectorFromString("requestClasses"))?.takeUnretainedValue(),
            let reqClasses: Set<AnyHashable> = reqRaw as? Set<AnyHashable>
        else {
            result["ok"] = false
            result["error"] = "\(appsClientClass) class or requestClasses unavailable"
            return result
        }

        result["ok"] = CreateAdaptor(appsServiceName, tierName, reqClasses, nil) != nil
        if result["ok"] as? Bool != true {
            result["error"] = "CreateAdaptor returned nil"
        }
        return result
    }

    /// Scan DiagnosticReports for any crash logs related to setapp-cli or setapp-xpc.
    private static func diagCrashReports() -> [String: Any] {
        let diagDir: String = NSString(string: "~/Library/Logs/DiagnosticReports").expandingTildeInPath
        var crashes: [String] = []
        if let contents: [String] = try? FileManager.default.contentsOfDirectory(atPath: diagDir) {
            crashes = contents
                .filter { $0.hasPrefix("setapp-cli") || $0.hasPrefix("setapp-xpc") }
                .sorted()
        }
        return [
            "check": "crashReports",
            "directory": diagDir,
            "count": crashes.count,
            "files": crashes,
            "ok": crashes.isEmpty
        ]
    }
}
