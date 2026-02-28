import CBridge
import Foundation

/// XPC service helper for communicating with Setapp's AppsManagement service.
///
/// Loads SetappInterface.framework via dlopen, creates an adaptor-based
/// bidirectional XPC connection, and sends install/uninstall requests.
enum XPCService {
    // MARK: - Constants

    /// Path to the SetappInterface framework binary, with a leading tilde.
    static let frameworkPath: String =
        "~/Library/Application Support/Setapp/LaunchAgents/" +
        "Setapp.app/Contents/Frameworks/" +
        "SetappInterface.framework/SetappInterface"

    /// Mach service name for Setapp's apps-management XPC endpoint.
    static let appsServiceName: String = "com.setapp.AppsManagementService"

    /// ObjC class name for the apps-management client.
    static let appsClientClass: String = "AFXAppsManagementClient"

    /// Tier name used by the XPC protocol for the AppsManagement tier.
    static let tierName: String = "AppsManagement"

    /// Timeout in seconds for install requests.
    private static let timeoutInstall: TimeInterval = 180

    /// Timeout in seconds for uninstall requests.
    private static let timeoutUninstall: TimeInterval = 60

    /// Timeout in seconds for fetch-app-by-ID requests.
    private static let timeoutFetch: TimeInterval = 30

    // MARK: - Framework Loading

    /// Load SetappInterface.framework via dlopen.
    ///
    /// The binary must be compiled with `-rpath` pointing at Setapp's Frameworks
    /// directory so that @rpath dependencies (AgentHealthMetrics, etc.) resolve.
    static func loadFramework() throws {
        let path: String = NSString(string: frameworkPath).expandingTildeInPath
        Printer.debug("Loading framework from: \(path)")

        guard dlopen(path, RTLD_NOW | RTLD_GLOBAL) != nil else {
            throw SetappError.frameworkLoadFailed(message: String(cString: dlerror()))
        }

        Printer.debug("SetappInterface loaded")
    }
}

// MARK: - Adaptor Creation

extension XPCService {
    /// Create an AFXRegularInterprocessClientAdaptor for the AppsManagement service.
    private static func createAdaptor() throws -> AnyObject {
        guard let clientClass: AnyClass = NSClassFromString(appsClientClass) else {
            throw SetappError.xpcConnectionFailed(message: "\(appsClientClass) class not found")
        }

        let requestClassesRaw: AnyObject? = (clientClass as AnyObject)
            .perform(NSSelectorFromString("requestClasses"))?
            .takeUnretainedValue()
        guard let requestClasses: Set<AnyHashable> = requestClassesRaw as? Set<AnyHashable> else {
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
        if
            let envIDClass: AnyClass = NSClassFromString("AFXEnvironmentID"),
            let envID: AnyObject = (envIDClass as AnyObject)
                .perform(NSSelectorFromString("defaultEnvironmentID"))?.takeUnretainedValue(),
            let svcIDClass: AnyClass = NSClassFromString("AFXEnvironmentServiceID") {
            guard
                let allocated: AnyObject = (svcIDClass as AnyObject)
                    .perform(NSSelectorFromString("alloc"))?.takeUnretainedValue()
            else {
                throw SetappError.xpcConnectionFailed(
                    message: "Failed to alloc AFXEnvironmentServiceID"
                )
            }

            guard
                let svcID: AnyObject = allocated
                    .perform(
                        NSSelectorFromString("initWithServiceName:environmentID:"),
                        with: appsServiceName as NSString,
                        with: envID
                    )?
                    .takeUnretainedValue()
            else {
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
}

// MARK: - Request Sending

extension XPCService {
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
        var completed: Bool = false

        Printer.debug("Sending request...")

        AdaptorPerformRequest(
            adaptor,
            request,
            { report in
                guard let report else {
                    return
                }
                let reportClass: String = .init(cString: object_getClassName(report as AnyObject))
                Printer.debug("Report received: \(reportClass)")

                if let terminateClass: String = terminateOnReportClass, reportClass == terminateClass {
                    Printer.debug("Completion report \(terminateClass) received")
                    responseValue = report as AnyObject
                    completed = true
                    CFRunLoopStop(CFRunLoopGetMain())
                }
            },
            { response in
                responseValue = response as AnyObject?
                completed = true
                CFRunLoopStop(CFRunLoopGetMain())
            }
        )

        let deadline: Date = .init(timeIntervalSinceNow: timeout)
        while !completed, Date() < deadline {
            let remaining: TimeInterval = deadline.timeIntervalSinceNow
            if remaining <= 0 {
                break
            }
            CFRunLoopRunInMode(.defaultMode, min(remaining, 1.0), true)
        }

        if !completed {
            Printer.debug("Request timed out after \(timeout)s")
        }

        return responseValue
    }

    /// Check an XPC response for errors and throw if found.
    private static func checkResponse(_ response: AnyObject) throws {
        let errorSel: Selector = NSSelectorFromString("error")
        if
            response.responds(to: errorSel),
            let error: AnyObject = response.perform(errorSel)?.takeUnretainedValue() {
            let desc: String = (error as AnyObject)
                .perform(NSSelectorFromString("localizedDescription"))?
                .takeUnretainedValue() as? String ?? "\(error)"
            throw SetappError.xpcRequestFailed(message: desc)
        }
    }

    /// Fetch an app's catalogue entry by numeric ID.
    private static func fetchAppObject(
        id: Int, adaptor: AnyObject, serviceID: AnyObject
    ) throws -> AnyObject {
        guard let reqClass: AnyClass = NSClassFromString("AFXFetchAppByIDRequest") else {
            throw SetappError.xpcRequestFailed(message: "AFXFetchAppByIDRequest class not found")
        }

        guard
            let allocated: AnyObject = (reqClass as AnyObject)
                .perform(NSSelectorFromString("alloc"))?.takeUnretainedValue(),
            let request: AnyObject = allocated
                .perform(NSSelectorFromString("init"))?.takeUnretainedValue()
        else {
            throw SetappError.xpcRequestFailed(
                message: "Failed to instantiate AFXFetchAppByIDRequest"
            )
        }

        _ = request.perform(NSSelectorFromString("setAppID:"), with: NSNumber(value: id))
        _ = request.perform(NSSelectorFromString("setServiceID:"), with: serviceID)
        _ = request.perform(
            NSSelectorFromString("setRequestingTierName:"),
            with: tierName as NSString
        )

        Printer.debug("Fetching app by ID \(id)")

        guard
            let responseRaw: AnyObject = sendRequest(
                request,
                via: adaptor,
                timeout: timeoutFetch
            ) else {
            throw SetappError.xpcRequestTimedOut(seconds: Int(timeoutFetch))
        }

        let responseObj: AnyObject = responseRaw as AnyObject
        try checkResponse(responseObj)

        // Unwrap MPValueOrError if present
        let valueSel: Selector = NSSelectorFromString("value")
        let appSel: Selector = NSSelectorFromString("app")

        if
            responseObj.responds(to: valueSel),
            let value: AnyObject = responseObj.perform(valueSel)?.takeUnretainedValue() {
            let valueObj: AnyObject = value as AnyObject
            if
                valueObj.responds(to: appSel),
                let appObj: AnyObject = valueObj.perform(appSel)?.takeUnretainedValue() {
                return appObj as AnyObject
            }
            return valueObj
        }

        if
            responseObj.responds(to: appSel),
            let appObj: AnyObject = responseObj.perform(appSel)?.takeUnretainedValue() {
            return appObj as AnyObject
        }

        return responseObj
    }
}

// MARK: - Public API

extension XPCService {
    /// Install a Setapp app by its numeric ID.
    static func install(appID: Int) throws {
        try loadFramework()
        let adaptor: AnyObject = try createAdaptor()
        let serviceID: AnyObject = try createServiceID()
        let appObj: AnyObject = try fetchAppObject(
            id: appID,
            adaptor: adaptor,
            serviceID: serviceID
        )

        guard let reqClass: AnyClass = NSClassFromString("AFXInstallVendorAppRequest") else {
            throw SetappError.xpcRequestFailed(
                message: "AFXInstallVendorAppRequest class not found"
            )
        }

        guard
            let allocated: AnyObject = (reqClass as AnyObject)
                .perform(NSSelectorFromString("alloc"))?.takeUnretainedValue(),
            let request: AnyObject = allocated
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
            NSSelectorFromString("setRequestingTierName:"),
            with: tierName as NSString
        )

        Printer.debug("Sending install request for app ID \(appID)")

        guard
            let response: AnyObject = sendRequest(
                request,
                via: adaptor,
                timeout: timeoutInstall
            ) else {
            throw SetappError.xpcRequestTimedOut(seconds: Int(timeoutInstall))
        }

        try checkResponse(response)
    }

    /// Uninstall a Setapp app by its numeric ID.
    static func uninstall(appID: Int) throws {
        try loadFramework()
        let adaptor: AnyObject = try createAdaptor()
        let serviceID: AnyObject = try createServiceID()
        let appObj: AnyObject = try fetchAppObject(
            id: appID,
            adaptor: adaptor,
            serviceID: serviceID
        )

        guard let reqClass: AnyClass = NSClassFromString("AFXUninstallVendorAppRequest") else {
            throw SetappError.xpcRequestFailed(
                message: "AFXUninstallVendorAppRequest class not found"
            )
        }

        guard
            let allocated: AnyObject = (reqClass as AnyObject)
                .perform(NSSelectorFromString("alloc"))?.takeUnretainedValue(),
            let request: AnyObject = allocated
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
            NSSelectorFromString("setRequestingTierName:"),
            with: tierName as NSString
        )

        Printer.debug("Sending uninstall request for app ID \(appID)")

        guard
            let response: AnyObject = sendRequest(
                request,
                via: adaptor,
                timeout: timeoutUninstall,
                terminateOnReportClass: "AFXUninstallAppsCompletionReport"
            )
        else {
            throw SetappError.xpcRequestTimedOut(seconds: Int(timeoutUninstall))
        }

        try checkResponse(response)
    }
}
