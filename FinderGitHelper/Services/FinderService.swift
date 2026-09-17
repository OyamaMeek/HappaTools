import AppKit
import Carbon

actor FinderService {
    static let pathScript = """
    with timeout of 10 seconds
        tell application "Finder"
            if (count of Finder windows) is 0 then return ""
            set currentFolder to (target of front window) as alias
            return POSIX path of currentFolder
        end tell
    end timeout
    """

    static let refreshScript = """
    on refreshFolder(folderPath)
        with timeout of 10 seconds
            tell application "Finder" to update (POSIX file folderPath as alias)
        end timeout
    end refreshFolder
    """

    /// 读取最前方 Finder 窗口；actor 串行执行 AppleScript，避免阻塞 UI。
    func currentPath() -> FinderPathResult {
        switch execute(source: Self.pathScript) {
        case .success(let descriptor):
            guard let path = descriptor.stringValue else {
                return .error(.scriptFailed("Finder returned no path."))
            }
            return Self.parsePath(path)
        case .failure(let error):
            return .error(error)
        }
    }

    /// 文件路径通过 Apple Event 参数传递，避免插入 AppleScript 源码。
    func refreshDirectory(at url: URL) -> Result<Void, FinderError> {
        let event = NSAppleEventDescriptor(
            eventClass: AEEventClass(kASAppleScriptSuite),
            eventID: AEEventID(kASSubroutineEvent),
            targetDescriptor: nil,
            returnID: AEReturnID(kAutoGenerateReturnID),
            transactionID: AETransactionID(kAnyTransactionID)
        )
        event.setParam(NSAppleEventDescriptor(string: "refreshfolder"), forKeyword: AEKeyword(keyASSubroutineName))
        let arguments = NSAppleEventDescriptor.list()
        arguments.insert(NSAppleEventDescriptor(string: url.path), at: 1)
        event.setParam(arguments, forKeyword: AEKeyword(keyDirectObject))
        return execute(source: Self.refreshScript, event: event).map { _ in () }
    }

    static func parsePath(_ path: String) -> FinderPathResult {
        guard !path.isEmpty else { return .noWindow }
        var isDirectory: ObjCBool = false
        guard path.hasPrefix("/"),
              FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return .error(.unsupportedLocation(path))
        }
        return .success(URL(fileURLWithPath: path).standardizedFileURL.path)
    }

    private func execute(source: String, event: NSAppleEventDescriptor? = nil) -> Result<NSAppleEventDescriptor, FinderError> {
        guard let script = NSAppleScript(source: source) else {
            return .failure(.scriptFailed("Could not create AppleScript."))
        }
        var details: NSDictionary?
        let result: NSAppleEventDescriptor
        if let event = event {
            result = script.executeAppleEvent(event, error: &details)
        } else {
            result = script.executeAndReturnError(&details)
        }
        if let details = details {
            if (details[NSAppleScript.errorNumber] as? NSNumber)?.intValue == -1743 {
                return .failure(.automationDenied(details.description))
            }
            return .failure(.scriptFailed(details.description))
        }
        return .success(result)
    }
}
