import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        Form {
            TextField("Default branch", text: $viewModel.defaultBranch)
                .textFieldStyle(.roundedBorder)
            Text("Must match the folder's current Git branch. Changes are saved automatically.")
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Toggle("Show Git Button", isOn: $viewModel.showGitButton)
            Toggle("Show README Button", isOn: $viewModel.showReadmeButton)
        }
        .padding(24)
        .frame(width: 420)
    }
}
