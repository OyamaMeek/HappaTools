import Foundation

public struct FinderRequest {
    public enum Operation: String {
        case git
        case readme
    }

    public let operation: Operation
    public let directory: URL?

    public init(operation: Operation, directory: URL?) {
        self.operation = operation
        self.directory = directory
    }

    public var url: URL {
        var components = URLComponents()
        components.scheme = "happatools"
        components.host = operation.rawValue
        if let directory {
            components.queryItems = [URLQueryItem(name: "path", value: directory.path)]
        }
        return components.url!
    }

    public init(url: URL) throws {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme?.lowercased() == "happatools",
              let host = components.host,
              let operation = Operation(rawValue: host),
              components.user == nil,
              components.password == nil,
              components.port == nil,
              components.fragment == nil,
              components.path.isEmpty || components.path == "/" else {
            throw FinderRequestError.invalidURL
        }

        let queryItems = components.queryItems ?? []
        guard queryItems.count <= 1,
              queryItems.allSatisfy({ $0.name == "path" }) else {
            throw FinderRequestError.invalidURL
        }

        let directory: URL?
        if let item = queryItems.first {
            guard let path = item.value,
                  path.hasPrefix("/"),
                  !path.contains("\0") else {
                throw FinderRequestError.invalidURL
            }
            directory = URL(fileURLWithPath: path, isDirectory: true)
        } else {
            directory = nil
        }

        self.operation = operation
        self.directory = directory
    }
}

public enum FinderRequestError: LocalizedError {
    case invalidURL

    public var errorDescription: String? {
        "无效的 HappaTools 请求"
    }
}
