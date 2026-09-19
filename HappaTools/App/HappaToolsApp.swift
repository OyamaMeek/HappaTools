import SwiftUI

@main
struct HappaToolsApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
                .frame(minWidth: 820, minHeight: 540)
                .onAppear { model.start() }
                .onOpenURL { model.handle($0) }
        }
        Settings {
            SettingsView().environmentObject(model).padding(24).frame(width: 560)
        }
    }
}
