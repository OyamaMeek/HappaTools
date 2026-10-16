import Foundation
import HappaToolsShared

final class GitOperationHandler {
    private(set) var isWorking = false

    func perform(at directory: URL, operation: FinderRequest.Operation, message: String?, completion: @escaping (Result<URL?, Error>) -> Void) {
        guard !isWorking else { return }
        isWorking = true
        DispatchQueue.global(qos: .userInitiated).async {
            let result: Result<URL?, Error>
            do {
                let settings = UserSettings()
                let database = try DatabaseManager(url: AppGroupConfig.databaseURL())
                try database.cleanupOldLogs(olderThan: Date().addingTimeInterval(-30 * 86_400))
                switch operation {
                case .git, .pull:
                    let executor = GitExecutor(executableURL: URL(fileURLWithPath: settings.gitExecutablePath))
                    let workflow = GitWorkflow(executor: executor, database: database)
                    if operation == .pull {
                        try workflow.pull(at: directory)
                    } else {
                        guard let message = message else { throw GitError.blankCommitMessage }
                        try workflow.commitAndPush(at: directory, message: message, preferredBranch: settings.defaultBranch)
                    }
                    result = .success(nil)
                case .readme:
                    result = .success(try ReadmeCreator.create(at: directory, database: database))
                case .iterm:
                    throw FinderRequestError.invalidURL
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
