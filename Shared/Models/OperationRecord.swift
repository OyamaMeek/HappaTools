import Foundation

public struct OperationRecord: Identifiable, Equatable {
    public let id: Int64
    public let timestamp: Date
    public let operationType: String
    public let targetPath: String
    public let commitMessage: String?
    public let stdout: String
    public let stderr: String
    public let status: String

    public init(
        id: Int64 = 0,
        timestamp: Date = Date(),
        operationType: String,
        targetPath: String,
        commitMessage: String? = nil,
        stdout: String = "",
        stderr: String = "",
        status: String
    ) {
        self.id = id
        self.timestamp = timestamp
        self.operationType = operationType
        self.targetPath = targetPath
        self.commitMessage = commitMessage
        self.stdout = stdout
        self.stderr = stderr
        self.status = status
    }
}
