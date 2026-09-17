import SwiftUI

struct CommitMessageView: View {
    let request: CommitRequest
    let cancel: () -> Void
    let commit: (String) -> Void
    @State private var message = DateFormatter.commitMessage()
    @FocusState private var editorFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Commit & Push").font(.title2.bold())
            Text(request.path.path).font(.callout).textSelection(.enabled)
            Text("Branch: \(request.branch) → origin").foregroundColor(.secondary)
            Text("Commit message").font(.headline)
            TextEditor(text: $message)
                .font(.system(.body, design: .monospaced))
                .focused($editorFocused)
                .frame(height: 130)
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.secondary.opacity(0.3)))
                .accessibilityLabel("Commit message")
            Text("Stages all non-ignored changes in this folder. The commit also includes any changes already staged elsewhere in this repository. Check your .gitignore before continuing.")
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Button("Cancel", action: cancel).keyboardShortcut(.cancelAction)
                Spacer()
                Button("Commit & Push") { commit(message) }
                    .keyboardShortcut(.return, modifiers: [.command])
                    .disabled(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 490)
        .onAppear { editorFocused = true }
    }
}
