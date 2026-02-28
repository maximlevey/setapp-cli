import Foundation
import CBridge

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

        for i in 0..<Int(count) {
            let clsRaw = rawPtr.load(fromByteOffset: i * ptrSize, as: UnsafeRawPointer.self)
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
        for cls in classes { set.add(cls) }
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
           let svcIDClass: AnyClass = NSClassFromString("AFXEnvironmentServiceID") {

            guard let allocated = (svcIDClass as AnyObject)
                .perform(NSSelectorFromString("alloc"))?.takeUnretainedValue() else {
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
           let error = response.perform(errorSel)?.takeUnretainedValue() {
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
            .perform(NSSelectorFromString("init"))?.takeUnretainedValue() else {
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
           let value = responseObj.perform(valueSel)?.takeUnretainedValue() {
            let valueObj = value as AnyObject
            if valueObj.responds(to: appSel),
               let appObj = valueObj.perform(appSel)?.takeUnretainedValue() {
                return appObj as AnyObject
            }
            return valueObj
        }

        if responseObj.responds(to: appSel),
           let appObj = responseObj.perform(appSel)?.takeUnretainedValue() {
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
            .perform(NSSelectorFromString("init"))?.takeUnretainedValue() else {
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
            .perform(NSSelectorFromString("init"))?.takeUnretainedValue() else {
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

    /// Run diagnostics and return results as JSON string.
    static func diag() throws -> String {
        var results: [[String: Any]] = []

        // 1. Bundle identifier
        let bundleID = Bundle.main.bundleIdentifier ?? "<nil>"
        results.append([
            "check": "bundleIdentifier",
            "value": bundleID,
            "ok": Bundle.main.bundleIdentifier != nil,
        ])

        // 2. Framework exists
        let fwPath = NSString(string: frameworkPath).expandingTildeInPath
        let fwExists = FileManager.default.fileExists(atPath: fwPath)
        results.append([
            "check": "frameworkExists",
            "path": fwPath,
            "ok": fwExists,
        ])

        // 3. dlopen
        var dlopenOK = false
        var dlopenError = ""
        if fwExists {
            if dlopen(fwPath, RTLD_NOW | RTLD_GLOBAL) != nil {
                dlopenOK = true
            } else {
                dlopenError = String(cString: dlerror())
            }
        } else {
            dlopenError = "framework binary not found"
        }
        var dlopenResult: [String: Any] = ["check": "dlopen", "ok": dlopenOK]
        if !dlopenOK { dlopenResult["error"] = dlopenError }
        results.append(dlopenResult)

        // 4. AFX class count
        let afxClasses = allAFXClassList()
        results.append([
            "check": "afxClassCount",
            "value": afxClasses.count,
            "ok": afxClasses.count > 0,
        ])

        // 5. Expected selectors
        let expectedSelectors = [
            "installVendorApp:shouldLaunch:callback:",
            "fetchAppsWithCallback:",
            "fetchAppWithID:callback:",
        ]
        var selectorResults: [[String: Any]] = []
        var clientClassFound = false

        if let clientClass: AnyClass = NSClassFromString(appsClientClass) {
            clientClassFound = true
            var methodCount: UInt32 = 0
            let methods = class_copyMethodList(clientClass, &methodCount)
            var methodNames: [String] = []
            if let methods {
                for i in 0..<Int(methodCount) {
                    methodNames.append(String(cString: sel_getName(method_getName(methods[i]))))
                }
                free(methods)
            }
            for sel in expectedSelectors {
                selectorResults.append(["selector": sel, "found": methodNames.contains(sel)])
            }
        } else {
            for sel in expectedSelectors {
                selectorResults.append(["selector": sel, "found": false])
            }
        }
        results.append([
            "check": "expectedSelectors",
            "class": appsClientClass,
            "classFound": clientClassFound,
            "selectors": selectorResults,
            "ok": selectorResults.allSatisfy { ($0["found"] as? Bool) == true },
        ])

        // 6. Adaptor probe
        var probeOK = false
        var probeError = ""
        if dlopenOK {
            if let cls: AnyClass = NSClassFromString(appsClientClass),
               let reqRaw = (cls as AnyObject)
                   .perform(NSSelectorFromString("requestClasses"))?.takeUnretainedValue(),
               let reqClasses = reqRaw as? Set<AnyHashable> {
                if CreateAdaptor(appsServiceName, tierName, reqClasses, nil) != nil {
                    probeOK = true
                } else {
                    probeError = "CreateAdaptor returned nil"
                }
            } else {
                probeError = "\(appsClientClass) class or requestClasses unavailable"
            }
        } else {
            probeError = "framework not loaded"
        }
        var probeResult: [String: Any] = [
            "check": "appsManagementAdaptorProbe",
            "service": appsServiceName,
            "ok": probeOK,
        ]
        if !probeOK { probeResult["error"] = probeError }
        results.append(probeResult)

        // 7. Crash reports
        let diagDir = NSString(string: "~/Library/Logs/DiagnosticReports").expandingTildeInPath
        var crashes: [String] = []
        if let contents = try? FileManager.default.contentsOfDirectory(atPath: diagDir) {
            crashes = contents.filter { $0.hasPrefix("setapp-cli") || $0.hasPrefix("setapp-xpc") }
                .sorted()
        }
        results.append([
            "check": "crashReports",
            "directory": diagDir,
            "count": crashes.count,
            "files": crashes,
            "ok": crashes.isEmpty,
        ])

        let jsonDict: [String: Any] = ["diag": results]
        let data = try JSONSerialization.data(
            withJSONObject: jsonDict, options: [.prettyPrinted, .sortedKeys]
        )
        return String(data: data, encoding: .utf8) ?? "{}"
    }
}
