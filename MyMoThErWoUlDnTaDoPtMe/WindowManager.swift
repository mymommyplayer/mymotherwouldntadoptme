import SwiftUI

struct WindowManager: Scene {
    static let minimumSize = CGSize(width: 800, height: 500)
    static let aspectRatio: CGFloat = 1000.0 / 650.0

    var body: some Scene {
        WindowGroup {
            ContentView()
                .background(Color.black)
                .onAppear {
                    if let window = NSApp.windows.first(where: { $0.isKeyWindow }) {
                        window.minSize = minimumSize
                        window.setContentSize(NSSize(width: 1000, height: 650))
                        window.aspectRatio = NSSize(width: aspectRatio, height: 1.0)
                    }
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 1000, height: 650)
    }
}
