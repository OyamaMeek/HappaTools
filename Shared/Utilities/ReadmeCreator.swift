import Darwin
import Foundation

public enum ReadmeError: LocalizedError {
    case alreadyExists
    case creationFailed(code: Int32)

    public var errorDescription: String? {
        switch self {
        case .alreadyExists:
            return "README.md 已存在"
        case let .creationFailed(code):
            return "无法创建 README.md（错误码 \(code)）"
        }
    }
}

public enum ReadmeCreator {
    public static func create(at directory: URL, database: DatabaseManager) throws -> URL {
        let url = directory.appendingPathComponent("README.md", isDirectory: false)
        let descriptor = open(url.path, O_WRONLY | O_CREAT | O_EXCL, S_IRUSR | S_IWUSR | S_IRGRP | S_IROTH)
        guard descriptor >= 0 else {
            let error: ReadmeError = errno == EEXIST ? .alreadyExists : .creationFailed(code: errno)
            try database.insertLog(OperationRecord(
                operationType: "create_readme",
                targetPath: directory.path,
                stderr: error.localizedDescription,
                status: "failure"
            ))
            throw error
        }
        guard close(descriptor) == 0 else {
            let error = ReadmeError.creationFailed(code: errno)
            try database.insertLog(OperationRecord(
                operationType: "create_readme",
                targetPath: directory.path,
                stderr: error.localizedDescription,
                status: "failure"
            ))
            throw error
        }
        try database.insertLog(OperationRecord(
            operationType: "create_readme",
            targetPath: directory.path,
            status: "success"
        ))
        return url
    }
}
