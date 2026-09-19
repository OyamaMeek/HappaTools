import Foundation
import HappaToolsShared

final class GitOperationHandler {
    private(set) var isWorking = false

    func perform(at directory: URL, message: String?, completion: @escaping (Result<URL?, Error>) -> Void) {
        guard !isWorking else { return }
        isWorking = true
        DispatchQueue.global(qos: .userInitiated).async {
            let result: Result<URL?, Error>
            do {
                let settings = UserSettings()
                let database = try DatabaseManager(url: AppGroupConfig.databaseURL())
                try database.cleanupOldLogs(olderThan: Date().addingTimeInterval(-30 * 86_400))
                if let message = message {
                    let executor = GitExecutor(executableURL: URL(fileURLWithPath: settings.gitExecutablePath))
                    try GitWorkflow(executor: executor, database: database).commitAndPush(at: directory, message: message, preferredBranch: settings.defaultBranch)
                    result = .success(nil)
                } else {
                    result = .success(try ReadmeCreator.create(at: directory, database: database))
                }
            } catch {
                result = .failure(error)
            }
            DispatchQueue.main.async {
                self.isWorking = false
                completion(result)
            }
        }
    }
}
