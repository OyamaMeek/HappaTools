import Combine

final class SettingsViewModel: ObservableObject {
    private let settings: AppSettings
    private var observation: AnyCancellable?

    init(settings: AppSettings) {
        self.settings = settings
        observation = settings.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }
    }

    var defaultBranch: String {
        get { settings.defaultBranch }
        set { settings.defaultBranch = newValue }
    }

    var showGitButton: Bool {
        get { settings.showGitButton }
        set { settings.showGitButton = newValue }
    }

    var showReadmeButton: Bool {
        get { settings.showReadmeButton }
        set { settings.showReadmeButton = newValue }
    }
}
