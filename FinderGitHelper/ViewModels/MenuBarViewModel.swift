import AppKit
import Combine

struct CommitRequest: Identifiable {
    let id = UUID()
    let path: URL
    let branch: String
}

struct OperationFailure: Identifiable {
    let id = UUID()
    let details: String
    var isPermissionDenied = false
}

@MainActor
final class MenuBarViewModel: ObservableObject {
    @Published private(set) var currentPath: String?
    @Published private(set) var isLoading = false
    @Published private(set) var isRefreshing = false
    @Published private(set) var readmeExists = false
    @Published private(set) var pathMessage = "Reading Finder…"
    @Published private(set) var statusMessage: String?
    // ponytail: 仅保留最近一次失败推送；需要跨仓库恢复时改为按仓库持久化。
    @Published private(set) var pendingPush: CommitRequest?
    @Published var commitRequest: CommitRequest?
    @Published var failure: OperationFailure?

    let settings: AppSettings
    private let finder = FinderService()
    private let git = GitService()
    private let notifications = NotificationService()

    init(settings: AppSettings) {
        self.settings = settings
    }

    func refreshFinderPath() {
        guard !isRefreshing else { return }
        isRefreshing = true
        Task {
            let result = await finder.currentPath()
            switch result {
            case .success(let path):
                currentPath = path
                pathMessage = path
                let directory = URL(fileURLWithPath: path, isDirectory: true)
                readmeExists = await Task.detached { ReadmeService.exists(at: directory) }.value
            case .noWindow:
                currentPath = nil
                readmeExists = false
                pathMessage = "No Finder window"
            case .error(let error):
                currentPath = nil
                readmeExists = false
                pathMessage = error.isPermissionDenied ? "Finder permission required" : "Finder folder unavailable"
                failure = OperationFailure(details: error.localizedDescription, isPermissionDenied: error.isPermissionDenied)
            }
            isRefreshing = false
        }
    }

    func prepareCommit() {
        guard let path = currentPath, !isLoading, !isRefreshing else { return }
        commitRequest = CommitRequest(
            path: URL(fileURLWithPath: path, isDirectory: true),
            branch: settings.defaultBranch.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    func executeGitOperation(_ message: String, request: CommitRequest) {
        guard !isLoading else { return }
        commitRequest = nil
        isLoading = true
        statusMessage = "Committing and pushing to \(request.branch)…"
        let service = git
        Task {
            let result = await Task.detached(priority: .userInitiated) {
                service.commitAndPush(message: message, branch: request.branch, path: request.path)
            }.value
            finishGit(result, request: request)
        }
    }

    func retryPush() {
        guard let request = pendingPush, !isLoading else { return }
        isLoading = true
        statusMessage = "Retrying push to \(request.branch)…"
        let service = git
        Task {
            let result = await Task.detached(priority: .userInitiated) {
                service.retryPush(branch: request.branch, path: request.path)
            }.value
            finishGit(result, request: request)
        }
    }

    func createReadme() {
        guard let path = currentPath, !isLoading, !isRefreshing else { return }
        let directory = URL(fileURLWithPath: path, isDirectory: true)
        isLoading = true
        statusMessage = "Creating README.md…"
        Task {
            let result = await Task.detached(priority: .userInitiated) {
                Result { try ReadmeService.create(at: directory) }
            }.value
            switch result {
            case .success:
                statusMessage = "README.md created successfully"
                notifications.send(title: "FinderGitHelper", message: "README.md created successfully")
                if case .failure(let error) = await finder.refreshDirectory(at: directory) {
                    failure = OperationFailure(
                        details: "README.md was created, but Finder could not refresh.\n\n\(error.localizedDescription)",
                        isPermissionDenied: error.isPermissionDenied
                    )
                }
            case .failure(let error):
                statusMessage = "README creation failed"
                failure = OperationFailure(details: "Could not create README.md. Check folder permissions and whether the file already exists. Existing files are never overwritten.\n\n\(error.localizedDescription)")
            }
            if currentPath == path {
                readmeExists = await Task.detached { ReadmeService.exists(at: directory) }.value
            }
            isLoading = false
        }
    }

    func openAutomationSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") else { return }
        NSWorkspace.shared.open(url)
    }

    private func finishGit(_ result: Result<Void, GitError>, request: CommitRequest) {
        isLoading = false
        switch result {
        case .success:
            if pendingPush?.path == request.path && pendingPush?.branch == request.branch { pendingPush = nil }
            statusMessage = "Changes pushed to \(request.branch)"
            notifications.send(title: "FinderGitHelper", message: "Changes pushed to \(request.branch)")
        case .failure(let error):
            if case .pushFailed = error { pendingPush = request }
            statusMessage = "Git operation failed"
            failure = OperationFailure(details: "Folder: \(request.path.path)\nBranch: \(request.branch)\n\n\(error.localizedDescription)")
            notifications.send(title: "Operation Failed", message: "Git operation failed. Open FinderGitHelper for details.")
        }
    }
}
