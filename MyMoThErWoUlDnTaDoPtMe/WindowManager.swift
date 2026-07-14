// Sources/MyMoThErWoUlDnTaDoPtMe/WindowManager.swift
import SwiftUI

struct WindowManager: Scene {
    static let minimumSize = CGSize(width: 800, height: 500)

    var body: some Scene {
        WindowGroup {
            ContentView()
                .background(Color.black)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 1000, height: 650)
    }
}
