import AppKit

final class RegistrationDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.terminate(nil)
    }
}

let delegate = RegistrationDelegate()
let app = NSApplication.shared
app.delegate = delegate
app.run()
