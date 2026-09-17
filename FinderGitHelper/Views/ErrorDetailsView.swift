import SwiftUI

struct ErrorDetailsView: View {
    let failure: OperationFailure
    let openSettings: () -> Void
    let dismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Operation Failed", systemImage: "exclamationmark.triangle")
                .font(.title2.bold())
            ScrollView {
                Text(failure.details)
                    .font(.system(.callout, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
            }
            .frame(height: 270)
            .background(Color.primary.opacity(0.04))
            HStack {
                Button("Copy Details") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(failure.details, forType: .string)
                }
                if failure.isPermissionDenied {
                    Button("Open Automation Settings", action: openSettings)
                }
                Spacer()
                Button("OK", action: dismiss).keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 560)
    }
}
