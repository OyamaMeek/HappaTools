import Foundation

enum FinderPathResult {
    case success(String)
    case noWindow
    case error(FinderError)
}

enum FinderError: LocalizedError {
    case automationDenied(String)
    case scriptFailed(String)
    case unsupportedLocation(String)

    var errorDescription: String? {
        switch self {
        case .automationDenied(let details):
            return "Allow FinderGitHelper to control Finder in System Settings → Privacy & Security → Automation, then try again.\n\n\(details)"
        case .scriptFailed(let details):
            return "Could not read the Finder folder. Open a normal folder in Finder and try again.\n\n\(details)"
        case .unsupportedLocation(let path):
            return "This Finder location is not an accessible filesystem folder. Open a local folder and try again.\n\n\(path)"
        }
    }

    var isPermissionDenied: Bool {
        if case .automationDenied = self { return true }
        return false
    }
}
