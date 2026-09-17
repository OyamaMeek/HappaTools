import SwiftUI

struct MenuBarContentView: View {
    @ObservedObject var viewModel: MenuBarViewModel
    @ObservedObject var settings: AppSettings
    let openSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("FinderGitHelper", systemImage: "terminal")
                    .font(.headline)
                Spacer()
                Button(action: viewModel.refreshFinderPath) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help("Refresh Finder folder")
                .accessibilityLabel("Refresh Finder folder")
                .disabled(viewModel.isRefreshing || viewModel.isLoading)
            }

            Text(viewModel.pathMessage)
                .font(.callout)
                .foregroundColor(.secondary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel("Finder folder: \(viewModel.pathMessage)")

            Divider()

            if settings.showGitButton {
                Button(action: viewModel.prepareCommit) {
                    Label("Commit & Push…", systemImage: "arrow.up.circle")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .disabled(actionsDisabled)
            }
            if settings.showReadmeButton && !viewModel.readmeExists {
                Button(action: viewModel.createReadme) {
                    Label("Create README.md", systemImage: "doc.badge.plus")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .disabled(actionsDisabled)
            }
            if let pending = viewModel.pendingPush {
                Button(action: viewModel.retryPush) {
                    Label("Retry Push to \(pending.branch)", systemImage: "arrow.clockwise.circle")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .disabled(viewModel.isLoading)
                Text("Pending push: \(pending.path.path)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let status = viewModel.statusMessage {
                HStack(spacing: 8) {
                    if viewModel.isLoading { ProgressView().controlSize(.small) }
                    Text(status).font(.caption).foregroundColor(.secondary)
                }
            }

            Divider()
            HStack {
                Button("Settings…", action: openSettings)
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
                    .disabled(viewModel.isLoading)
            }
        }
        .padding(16)
        .frame(width: 360)
        .sheet(item: $viewModel.commitRequest) { request in
            CommitMessageView(request: request, cancel: { viewModel.commitRequest = nil }) { message in
                viewModel.executeGitOperation(message, request: request)
            }
        }
        .sheet(item: $viewModel.failure) { failure in
            ErrorDetailsView(failure: failure, openSettings: viewModel.openAutomationSettings) {
                viewModel.failure = nil
            }
        }
    }

    private var actionsDisabled: Bool {
        viewModel.currentPath == nil || viewModel.isLoading || viewModel.isRefreshing
    }
}
