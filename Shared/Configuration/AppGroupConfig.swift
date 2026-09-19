import Foundation

public enum AppGroupConfig {
    public static let identifier = "group.com.happatools.shared"

    public static func containerURL() throws -> URL {
        guard let url = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: identifier
        ) else {
            throw AppGroupError.containerUnavailable
        }
        return url
    }

    public static func databaseURL() throws -> URL {
        try containerURL().appendingPathComponent("happatools.db")
    }
}

public enum AppGroupError: LocalizedError {
    case containerUnavailable

    public var errorDescription: String? {
        "无法访问 App Group 共享目录"
    }
}
