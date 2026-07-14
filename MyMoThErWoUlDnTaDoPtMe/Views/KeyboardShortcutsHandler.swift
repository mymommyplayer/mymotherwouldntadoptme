import SwiftUI

struct KeyboardShortcutsHandler: ViewModifier {
    let audioPlayer: AudioPlayer
    let queueManager: QueueManager
    let appState: AppState
    let discoveryManager: DiscoveryManager?
    @Binding var volume: Double
    @Binding var isControlCenterOpen: Bool
    @Binding var focusSearch: Bool
    @Binding var discoveryRefresh: Bool

    func body(content: Content) -> some View {
        content
            .overlay {
                Group {
                    Button("") { audioPlayer.toggle() }
                        .keyboardShortcut(.space, modifiers: [])
                        .frame(width: 0, height: 0).opacity(0).accessibilityHidden(true)

                    Button("") {
                        if appState.repeatMode == .repeatAll {
                            queueManager.nextRepeatAll()
                        } else {
                            queueManager.next()
                        }
                    }
                    .keyboardShortcut(.rightArrow, modifiers: [])
                    .frame(width: 0, height: 0).opacity(0).accessibilityHidden(true)

                    Button("") { queueManager.previous() }
                        .keyboardShortcut(.leftArrow, modifiers: [])
                        .frame(width: 0, height: 0).opacity(0).accessibilityHidden(true)

                    Button("") { appState.isShuffled.toggle() }
                        .keyboardShortcut("s", modifiers: [])
                        .frame(width: 0, height: 0).opacity(0).accessibilityHidden(true)

                    Button("") {
                        switch appState.repeatMode {
                        case .off: appState.repeatMode = .repeatAll
                        case .repeatAll: appState.repeatMode = .repeatOne
                        case .repeatOne: appState.repeatMode = .off
                        }
                    }
                    .keyboardShortcut("r", modifiers: [])
                    .frame(width: 0, height: 0).opacity(0).accessibilityHidden(true)

                    Button("") { discoveryManager?.toggle(); discoveryRefresh.toggle() }
                        .keyboardShortcut("l", modifiers: [])
                        .frame(width: 0, height: 0).opacity(0).accessibilityHidden(true)

                    Button("") { isControlCenterOpen.toggle() }
                        .keyboardShortcut(.escape, modifiers: [])
                        .frame(width: 0, height: 0).opacity(0).accessibilityHidden(true)

                    Button("") { audioPlayer.setVolume(min(1, Float(volume) + 0.1)); volume = min(1, volume + 0.1) }
                        .keyboardShortcut(.upArrow, modifiers: [])
                        .frame(width: 0, height: 0).opacity(0).accessibilityHidden(true)

                    Button("") { audioPlayer.setVolume(max(0, Float(volume) - 0.1)); volume = max(0, volume - 0.1) }
                        .keyboardShortcut(.downArrow, modifiers: [])
                        .frame(width: 0, height: 0).opacity(0).accessibilityHidden(true)

                    Button("") {
                        isControlCenterOpen = true
                        focusSearch = true
                    }
                    .keyboardShortcut("f", modifiers: [.command])
                    .frame(width: 0, height: 0).opacity(0).accessibilityHidden(true)
                }
            }
    }
}
