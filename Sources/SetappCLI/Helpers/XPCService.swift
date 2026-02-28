import CBridge
import Foundation

/// XPC service helper for communicating with Setapp's AppsManagement service.
///
/// Loads SetappInterface.framework via dlopen, creates an adaptor-based
/// bidirectional XPC connection, and sends install/uninstall requests.
enum XPCService {
    // MARK: - Constants

    private static let frameworkPath =
        "~/Library/Application Support/Setapp/LaunchAgents/" +
        "Setapp.app/Contents/Frameworks/" +
        "SetappInterface.framework/SetappInterface"

    private static let appsServiceName = "com.setapp.AppsManagementService"
    private static let appsClientClass = "AFXAppsManagementClient"
    private static let tierName = "AppsManagement"

    private static let timeoutInstall: TimeInterval = 180
    private static let timeoutUninstall: TimeInterval = 60
    private static let timeoutFetch: TimeInterval = 30

    // MARK: - Framework Loading

    /// Load SetappInterface.framework via dlopen.
    ///
    /// The binary must be compiled with `-rpath` pointing at Setapp's Frameworks
    /// directory so that @rpath dependencies (AgentHealthMetrics, etc.) resolve.
    static func loadFramework() throws {
        let path = NSString(string: frameworkPath).expandingTildeInPath
        Printer.debug("Loading framework from: \(path)")

        guard dlopen(path, RTLD_NOW | RTLD_GLOBAL) != nil else {
            throw SetappError.frameworkLoadFailed(message: String(cString: dlerror()))
        }

        Printer.debug("SetappInterface loaded")
    }

    // MARK: - Class Discovery

    /// Return names of all ObjC classes starting with "AFX".
    ///
    /// Uses raw pointer access to avoid swift_getObjectType crashes on
    /// unrealized metaclasses from complex frameworks.
    static func allAFXClassNames() -> [String] {
        var count: UInt32 = 0
        guard let classList = objc_copyClassList(&count) else { return [] }

        let rawPtr = UnsafeRawPointer(classList)
        let ptrSize = MemoryLayout<UnsafeRawPointer>.size
        var result: [String] = []

        for index in 0 ..< Int(count) {
            let clsRaw = rawPtr.load(fromByteOffset: index * ptrSize, as: UnsafeRawPointer.self)
            let cName = class_getName(unsafeBitCast(clsRaw, to: AnyClass.self))
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
        let classes = allAFXClassList()
        let set = NSMutableSet(capacity: classes.count)
        for cls in classes {
            set.add(cls)
        }
        return set.copy() as! NSSet
    }

    // MARK: - Adaptor Creation

    /// Create an AFXRegularInterprocessClientAdaptor for the AppsManagement service.
    private static func createAdaptor() throws -> AnyObject {
        guard let clientClass: AnyClass = NSClassFromString(appsClientClass) else {
            throw SetappError.xpcConnectionFailed(message: "\(appsClientClass) class not found")
        }

        let requestClassesRaw = (clientClass as AnyObject)
            .perform(NSSelectorFromString("requestClasses"))?.takeUnretainedValue()
        guard let requestClasses = requestClassesRaw as? Set<AnyHashable> else {
            throw SetappError.xpcConnectionFailed(
                message: "\(appsClientClass).requestClasses returned nil"
            )
        }

        Printer.debug("Request classes: \(requestClasses)")

        guard let adaptor = CreateAdaptor(appsServiceName, tierName, requestClasses, nil) else {
            throw SetappError.xpcConnectionFailed(
                message: "Failed to create adaptor for \(appsServiceName)"
            )
        }

        Printer.debug("Created adaptor: \(adaptor)")
        return adaptor as AnyObject
    }

    /// Create an AFXEnvironmentServiceID for the AppsManagement service.
    private static func createServiceID() throws -> AnyObject {
        // Try AFXEnvironmentServiceID first
        if let envIDClass: AnyClass = NSClassFromString("AFXEnvironmentID"),
           let envID = (envIDClass as AnyObject)
           .perform(NSSelectorFromString("defaultEnvironmentID"))?.takeUnretainedValue(),
           let svcIDClass: AnyClass = NSClassFromString("AFXEnvironmentServiceID")
        {
            guard let allocated = (svcIDClass as AnyObject)
                .perform(NSSelectorFromString("alloc"))?.takeUnretainedValue()
            else {
                throw SetappError.xpcConnectionFailed(
                    message: "Failed to alloc AFXEnvironmentServiceID"
                )
            }

            guard let svcID = allocated.perform(
                NSSelectorFromString("initWithServiceName:environmentID:"),
                with: appsServiceName as NSString,
                with: envID
            )?.takeUnretainedValue() else {
                throw SetappError.xpcConnectionFailed(
                    message: "Failed to init AFXEnvironmentServiceID"
                )
            }

            Printer.debug("Created AFXEnvironmentServiceID: \(svcID)")
            return svcID as AnyObject
        }

        // Fallback to AFXGlobalServiceID
        guard let serviceID = CreateGlobalServiceID(appsServiceName) else {
            throw SetappError.xpcConnectionFailed(
                message: "Both AFXEnvironmentServiceID and AFXGlobalServiceID unavailable"
            )
        }

        Printer.debug("Created AFXGlobalServiceID (fallback): \(serviceID)")
        return serviceID as AnyObject
    }

    // MARK: - Request Sending

    /// Send a request via the adaptor and wait for a response.
    ///
    /// Runs CFRunLoop to process XPC events until a response arrives or timeout.
    /// If `terminateOnReportClass` is set, also completes when a report of that
    /// class arrives (used for uninstall completion reports).
    private static func sendRequest(
        _ request: AnyObject,
        via adaptor: AnyObject,
        timeout: TimeInterval,
        terminateOnReportClass: String? = nil
    ) -> AnyObject? {
        var responseValue: AnyObject?
        var completed = false

        Printer.debug("Sending request...")

        AdaptorPerformRequest(adaptor, request, { report in
            guard let report else { return }
            let reportClass = String(cString: object_getClassName(report as AnyObject))
            Printer.debug("Report received: \(reportClass)")

            if let terminateClass = terminateOnReportClass, reportClass == terminateClass {
                Printer.debug("Completion report \(terminateClass) received")
                responseValue = report as AnyObject
                completed = true
                CFRunLoopStop(CFRunLoopGetMain())
            }
        }, { response in
            responseValue = response as AnyObject?
            completed = true
            CFRunLoopStop(CFRunLoopGetMain())
        })

        let deadline = Date(timeIntervalSinceNow: timeout)
        while !completed, Date() < deadline {
            let remaining = deadline.timeIntervalSinceNow
            if remaining <= 0 { break }
            CFRunLoopRunInMode(.defaultMode, min(remaining, 1.0), true)
        }

        if !completed {
            Printer.debug("Request timed out after \(timeout)s")
        }

        return responseValue
    }

    // MARK: - Response Handling

    /// Check an XPC response for errors and throw if found.
    private static func checkResponse(_ response: AnyObject) throws {
        let errorSel = NSSelectorFromString("error")
        if response.responds(to: errorSel),
           let error = response.perform(errorSel)?.takeUnretainedValue()
        {
            let desc = (error as AnyObject)
                .perform(NSSelectorFromString("localizedDescription"))?
                .takeUnretainedValue() as? String ?? "\(error)"
            throw SetappError.xpcRequestFailed(message: desc)
        }
    }

    // MARK: - App Object Fetching

    /// Fetch an app's catalogue entry by numeric ID.
    private static func fetchAppObject(
        id: Int, adaptor: AnyObject, serviceID: AnyObject
    ) throws -> AnyObject {
        guard let reqClass: AnyClass = NSClassFromString("AFXFetchAppByIDRequest") else {
            throw SetappError.xpcRequestFailed(message: "AFXFetchAppByIDRequest class not found")
        }

        guard let allocated = (reqClass as AnyObject)
            .perform(NSSelectorFromString("alloc"))?.takeUnretainedValue(),
            let request = allocated
            .perform(NSSelectorFromString("init"))?.takeUnretainedValue()
        else {
            throw SetappError.xpcRequestFailed(
                message: "Failed to instantiate AFXFetchAppByIDRequest"
            )
        }

        _ = request.perform(NSSelectorFromString("setAppID:"), with: NSNumber(value: id))
        _ = request.perform(NSSelectorFromString("setServiceID:"), with: serviceID)
        _ = request.perform(
            NSSelectorFromString("setRequestingTierName:"), with: tierName as NSString
        )

        Printer.debug("Fetching app by ID \(id)")

        guard let responseRaw = sendRequest(request, via: adaptor, timeout: timeoutFetch) else {
            throw SetappError.xpcRequestTimedOut(seconds: Int(timeoutFetch))
        }

        let responseObj = responseRaw as AnyObject
        try checkResponse(responseObj)

        // Unwrap MPValueOrError if present
        let valueSel = NSSelectorFromString("value")
        let appSel = NSSelectorFromString("app")

        if responseObj.responds(to: valueSel),
           let value = responseObj.perform(valueSel)?.takeUnretainedValue()
        {
            let valueObj = value as AnyObject
            if valueObj.responds(to: appSel),
               let appObj = valueObj.perform(appSel)?.takeUnretainedValue()
            {
                return appObj as AnyObject
            }
            return valueObj
        }

        if responseObj.responds(to: appSel),
           let appObj = responseObj.perform(appSel)?.takeUnretainedValue()
        {
            return appObj as AnyObject
        }

        return responseObj
    }

    // MARK: - Public API

    /// Install a Setapp app by its numeric ID.
    static func install(appID: Int) throws {
        try loadFramework()
        let adaptor = try createAdaptor()
        let serviceID = try createServiceID()
        let appObj = try fetchAppObject(id: appID, adaptor: adaptor, serviceID: serviceID)

        guard let reqClass: AnyClass = NSClassFromString("AFXInstallVendorAppRequest") else {
            throw SetappError.xpcRequestFailed(
                message: "AFXInstallVendorAppRequest class not found"
            )
        }

        guard let allocated = (reqClass as AnyObject)
            .perform(NSSelectorFromString("alloc"))?.takeUnretainedValue(),
            let request = allocated
            .perform(NSSelectorFromString("init"))?.takeUnretainedValue()
        else {
            throw SetappError.xpcRequestFailed(
                message: "Failed to instantiate AFXInstallVendorAppRequest"
            )
        }

        _ = request.perform(NSSelectorFromString("setApp:"), with: appObj)
        AFXSetScalarBool(request, NSSelectorFromString("setShouldLaunch:"), false)
        _ = request.perform(NSSelectorFromString("setServiceID:"), with: serviceID)
        _ = request.perform(
            NSSelectorFromString("setRequestingTierName:"), with: tierName as NSString
        )

        Printer.debug("Sending install request for app ID \(appID)")

        guard let response = sendRequest(request, via: adaptor, timeout: timeoutInstall) else {
            throw SetappError.xpcRequestTimedOut(seconds: Int(timeoutInstall))
        }

        try checkResponse(response)
    }

    /// Uninstall a Setapp app by its numeric ID.
    static func uninstall(appID: Int) throws {
        try loadFramework()
        let adaptor = try createAdaptor()
        let serviceID = try createServiceID()
        let appObj = try fetchAppObject(id: appID, adaptor: adaptor, serviceID: serviceID)

        guard let reqClass: AnyClass = NSClassFromString("AFXUninstallVendorAppRequest") else {
            throw SetappError.xpcRequestFailed(
                message: "AFXUninstallVendorAppRequest class not found"
            )
        }

        guard let allocated = (reqClass as AnyObject)
            .perform(NSSelectorFromString("alloc"))?.takeUnretainedValue(),
            let request = allocated
            .perform(NSSelectorFromString("init"))?.takeUnretainedValue()
        else {
            throw SetappError.xpcRequestFailed(
                message: "Failed to instantiate AFXUninstallVendorAppRequest"
            )
        }

        _ = request.perform(NSSelectorFromString("setApp:"), with: appObj)
        AFXSetScalarUInt64(request, NSSelectorFromString("setMode:"), 0)
        _ = request.perform(NSSelectorFromString("setServiceID:"), with: serviceID)
        _ = request.perform(
            NSSelectorFromString("setRequestingTierName:"), with: tierName as NSString
        )

        Printer.debug("Sending uninstall request for app ID \(appID)")

        guard let response = sendRequest(
            request, via: adaptor,
            timeout: timeoutUninstall,
            terminateOnReportClass: "AFXUninstallAppsCompletionReport"
        ) else {
            throw SetappError.xpcRequestTimedOut(seconds: Int(timeoutUninstall))
        }

        try checkResponse(response)
    }
}

// MARK: - Diagnostics

extension XPCService {
    /// Run diagnostics and return results as JSON string.
    static func diag() throws -> String {
        var results: [[String: Any]] = []
        let fwPath = NSString(string: frameworkPath).expandingTildeInPath
        let fwExists = FileManager.default.fileExists(atPath: fwPath)

        results.append(diagBundleID())
        results.append(diagFrameworkExists(path: fwPath, exists: fwExists))

        let dlopenOK = diagDlopen(path: fwPath, exists: fwExists)
        results.append(dlopenOK.result)

        results.append(diagAFXClasses())
        results.append(diagExpectedSelectors())
        results.append(diagAdaptorProbe(dlopenOK: dlopenOK.ok))
        results.append(diagCrashReports())

        let jsonDict: [String: Any] = ["diag": results]
        let data = try JSONSerialization.data(
            withJSONObject: jsonDict, options: [.prettyPrinted, .sortedKeys]
        )
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    private static func diagBundleID() -> [String: Any] {
        [
            "check": "bundleIdentifier",
            "value": Bundle.main.bundleIdentifier ?? "<nil>",
            "ok": Bundle.main.bundleIdentifier != nil,
        ]
    }

    private static func diagFrameworkExists(path: String, exists: Bool) -> [String: Any] {
        ["check": "frameworkExists", "path": path, "ok": exists]
    }

    private static func diagDlopen(
        path: String, exists: Bool
    ) -> (result: [String: Any], ok: Bool) {
        guard exists else {
            return (["check": "dlopen", "ok": false, "error": "framework binary not found"], false)
        }
        if dlopen(path, RTLD_NOW | RTLD_GLOBAL) != nil {
            return (["check": "dlopen", "ok": true], true)
        }
        let err = String(cString: dlerror())
        return (["check": "dlopen", "ok": false, "error": err], false)
    }

    private static func diagAFXClasses() -> [String: Any] {
        let afxClasses = allAFXClassList()
        return [
            "check": "afxClassCount",
            "value": afxClasses.count,
            "ok": !afxClasses.isEmpty,
        ]
    }

    private static func diagExpectedSelectors() -> [String: Any] {
        let expected = [
            "installVendorApp:shouldLaunch:callback:",
            "fetchAppsWithCallback:",
            "fetchAppWithID:callback:",
        ]
        var selectorResults: [[String: Any]] = []
        var clientClassFound = false

        if let clientClass: AnyClass = NSClassFromString(appsClientClass) {
            clientClassFound = true
            let methodNames = methodNamesForClass(clientClass)
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
            "ok": selectorResults.allSatisfy { ($0["found"] as? Bool) == true },
        ]
    }

    private static func methodNamesForClass(_ cls: AnyClass) -> [String] {
        var methodCount: UInt32 = 0
        let methods = class_copyMethodList(cls, &methodCount)
        var names: [String] = []
        if let methods {
            for index in 0 ..< Int(methodCount) {
                names.append(String(cString: sel_getName(method_getName(methods[index]))))
            }
            free(methods)
        }
        return names
    }

    private static func diagAdaptorProbe(dlopenOK: Bool) -> [String: Any] {
        var result: [String: Any] = [
            "check": "appsManagementAdaptorProbe",
            "service": appsServiceName,
        ]

        guard dlopenOK else {
            result["ok"] = false
            result["error"] = "framework not loaded"
            return result
        }

        guard let cls: AnyClass = NSClassFromString(appsClientClass),
              let reqRaw = (cls as AnyObject)
              .perform(NSSelectorFromString("requestClasses"))?.takeUnretainedValue(),
              let reqClasses = reqRaw as? Set<AnyHashable>
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

    private static func diagCrashReports() -> [String: Any] {
        let diagDir = NSString(string: "~/Library/Logs/DiagnosticReports").expandingTildeInPath
        var crashes: [String] = []
        if let contents = try? FileManager.default.contentsOfDirectory(atPath: diagDir) {
            crashes = contents.filter { $0.hasPrefix("setapp-cli") || $0.hasPrefix("setapp-xpc") }
                .sorted()
        }
        return [
            "check": "crashReports",
            "directory": diagDir,
            "count": crashes.count,
            "files": crashes,
            "ok": crashes.isEmpty,
        ]
    }
}
