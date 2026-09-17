import Combine
import Foundation

final class AppSettings: ObservableObject {
    static let defaultBranchKey = "defaultBranch"
    static let showGitButtonKey = "showGitButton"
    static let showReadmeButtonKey = "showReadmeButton"

    private let defaults: UserDefaults

    @Published var defaultBranch: String {
        didSet { defaults.set(defaultBranch, forKey: Self.defaultBranchKey) }
    }
    @Published var showGitButton: Bool {
        didSet { defaults.set(showGitButton, forKey: Self.showGitButtonKey) }
    }
    @Published var showReadmeButton: Bool {
        didSet { defaults.set(showReadmeButton, forKey: Self.showReadmeButtonKey) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Self.defaultBranchKey: "main",
            Self.showGitButtonKey: true,
            Self.showReadmeButtonKey: true
        ])
        defaultBranch = defaults.string(forKey: Self.defaultBranchKey) ?? "main"
        showGitButton = defaults.bool(forKey: Self.showGitButtonKey)
        showReadmeButton = defaults.bool(forKey: Self.showReadmeButtonKey)
    }
}
