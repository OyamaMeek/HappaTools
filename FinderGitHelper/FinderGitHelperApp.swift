import SwiftUI

@main
struct FinderGitHelperApp: App {
    @StateObject private var controller = StatusBarController()

    var body: some Scene {
        let settings = controller.settingsViewModel
        Settings { SettingsView(viewModel: settings) }
    }
}
