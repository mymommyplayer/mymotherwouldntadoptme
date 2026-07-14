import SwiftUI

@main
struct MyMoThErWoUlDnTaDoPtMeApp: App {
    @StateObject private var container = AppContainer()

    init() {
        UserDefaults.standard.register(defaults: SettingsKeys.defaults)
    }

    var body: some Scene {
        WindowManager()
            .environmentObject(container)
    }
}
