import Foundation

public final class UserSettings {
    private enum Key {
        static let defaultBranch = "happatools.defaultBranch"
        static let gitExecutablePath = "happatools.gitPath"
        static let showGitButton = "happatools.showGitButton"
        static let showReadmeButton = "happatools.showReadmeButton"
        static let hideFromDock = "happatools.hideFromDock"
        static let onboardingCompleted = "happatools.onboardingCompleted"
        static let operationInProgress = "happatools.operationInProgress"
    }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = UserDefaults(suiteName: AppGroupConfig.identifier)!) {
        self.defaults = defaults
    }

    public var defaultBranch: String {
        get { defaults.string(forKey: Key.defaultBranch) ?? "main" }
        set { store(newValue, forKey: Key.defaultBranch) }
    }

    public var gitExecutablePath: String {
        get {
            defaults.string(forKey: Key.gitExecutablePath) ?? [
                "/opt/homebrew/bin/git",
                "/usr/local/bin/git",
                "/usr/bin/git"
            ].first(where: FileManager.default.isExecutableFile(atPath:)) ?? "/usr/bin/git"
        }
        set { store(newValue, forKey: Key.gitExecutablePath) }
    }

    public var showGitButton: Bool {
        get { bool(forKey: Key.showGitButton, default: true) }
        set { store(newValue, forKey: Key.showGitButton) }
    }

    public var showReadmeButton: Bool {
        get { bool(forKey: Key.showReadmeButton, default: true) }
        set { store(newValue, forKey: Key.showReadmeButton) }
    }

    public var onboardingCompleted: Bool {
        get { bool(forKey: Key.onboardingCompleted, default: false) }
        set { store(newValue, forKey: Key.onboardingCompleted) }
    }

    public var hideFromDock: Bool {
        get { bool(forKey: Key.hideFromDock, default: false) }
        set { store(newValue, forKey: Key.hideFromDock) }
    }

    public var operationInProgress: Bool {
        get { bool(forKey: Key.operationInProgress, default: false) }
        set { store(newValue, forKey: Key.operationInProgress) }
    }

    private func bool(forKey key: String, default defaultValue: Bool) -> Bool {
        defaults.object(forKey: key) == nil ? defaultValue : defaults.bool(forKey: key)
    }

    private func store(_ value: Any, forKey key: String) {
        defaults.set(value, forKey: key)
        defaults.synchronize()
    }
}
