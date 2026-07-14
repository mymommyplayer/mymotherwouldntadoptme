import SwiftUI

enum SettingsKeys {
    static let crossfadeEnabled = "crossfadeEnabled"
    static let crossfadeDuration = "crossfadeDuration"
    static let streamExpiryIndex = "streamExpiryIndex"
    static let streamExpiryOverride = "streamExpiryOverride"
    static let rememberQueue = "rememberQueue"
    static let discoveryOnStartup = "discoveryOnStartup"
    static let discoveryModeEnabled = "discoveryModeEnabled"
    static let discoveryVariety = "discoveryVariety"
    static let pauseVideoOnMinimize = "pauseVideoOnMinimize"
    static let pauseVideoOnStop = "pauseVideoOnStop"
    static let defaultBackgroundMode = "defaultBackgroundMode"
    static let fadeTransition = "fadeTransition"
    static let lastBackgroundPlaylistURI = "lastBackgroundPlaylistURI"
    static let hasLaunchedBefore = "hasLaunchedBefore"

    static let defaults: [String: Any] = [
        crossfadeEnabled: false,
        crossfadeDuration: 3.0,
        streamExpiryIndex: 1,
        rememberQueue: false,
        discoveryOnStartup: false,
        discoveryVariety: 50.0,
        pauseVideoOnMinimize: true,
        pauseVideoOnStop: false,
        defaultBackgroundMode: BackgroundMode.system.rawValue,
        fadeTransition: true,
    ]
}

struct SettingsView: View {
    @State private var crossfadeEnabled = UserDefaults.standard.bool(forKey: SettingsKeys.crossfadeEnabled)
    @State private var crossfadeDuration = UserDefaults.standard.double(forKey: SettingsKeys.crossfadeDuration)
    @State private var streamExpiryIndex = UserDefaults.standard.integer(forKey: SettingsKeys.streamExpiryIndex)
    @State private var rememberQueue = UserDefaults.standard.bool(forKey: SettingsKeys.rememberQueue)
    @State private var discoveryOnStartup = UserDefaults.standard.bool(forKey: SettingsKeys.discoveryOnStartup)
    @State private var discoveryVariety = UserDefaults.standard.double(forKey: SettingsKeys.discoveryVariety)
    @State private var pauseVideoOnMinimize = UserDefaults.standard.bool(forKey: SettingsKeys.pauseVideoOnMinimize)
    @State private var pauseVideoOnStop = UserDefaults.standard.bool(forKey: SettingsKeys.pauseVideoOnStop)
    @State private var defaultBackgroundMode = BackgroundMode(
        rawValue: UserDefaults.standard.string(forKey: SettingsKeys.defaultBackgroundMode) ?? ""
    ) ?? .system
    @State private var fadeTransition = UserDefaults.standard.bool(forKey: SettingsKeys.fadeTransition)
    @State private var windowWidth: CGFloat = 800

    private let expiryOptions = ["30 min", "1 hour", "2 hours", "4 hours", "Custom"]
    @State private var customExpiryMinutes: String = {
        let override = UserDefaults.standard.double(forKey: SettingsKeys.streamExpiryOverride)
        if override > 0 {
            return String(Int(override / 60))
        }
        return ""
    }()

    var body: some View {
        ScrollView {
            GeometryReader { geo in
                Color.clear
                    .onAppear { windowWidth = geo.size.width }
                    .onChange(of: geo.size.width) { _, w in windowWidth = w }
            }
            .frame(height: 0)

            LazyVGrid(
                columns: windowWidth >= 800
                    ? [GridItem(.flexible(), spacing: Spacing.wide), GridItem(.flexible(), spacing: Spacing.wide)]
                    : [GridItem(.flexible())],
                spacing: Spacing.wide
            ) {
                playbackCard
                discoveryCard
                backgroundCard
                shortcutsCard
            }
            .padding(Spacing.wide)

            resetButton
                .padding(.horizontal, Spacing.wide)
                .padding(.bottom, Spacing.wide)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Card Container

    private func settingsCard<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            HStack(spacing: Spacing.tight) {
                Image(systemName: icon)
                    .font(AppFont.small)
                    .foregroundColor(.glassForegroundSecondary)
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.glassForeground)
                Spacer()
            }

            content()
        }
        .padding(Spacing.wide)
        .frame(maxHeight: .infinity)
        .background(.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: Radius.panel))
    }

    // MARK: - Playback Card

    private var playbackCard: some View {
        settingsCard(title: "Playback", icon: "play.circle") {
            VStack(alignment: .leading, spacing: Spacing.tight) {
                Toggle(isOn: $crossfadeEnabled.onChange(save: SettingsKeys.crossfadeEnabled)) {
                    Text("Crossfade")
                }
                .toggleStyle(.switch)
                .tint(.accentGlass)

                if crossfadeEnabled {
                    VStack(spacing: 4) {
                        labeledSlider(
                            value: $crossfadeDuration.onChange(save: SettingsKeys.crossfadeDuration),
                            range: 0.5...10,
                            step: 0.5,
                            label: "Duration: \(String(format: "%.1f", crossfadeDuration))s"
                        )
                    }
                    .padding(.leading, Spacing.medium)
                }

                Divider()
                    .overlay(Color.glassForegroundTertiary.opacity(0.15))

                Picker("Stream expiry", selection: $streamExpiryIndex.onChange(save: SettingsKeys.streamExpiryIndex)) {
                    ForEach(Array(expiryOptions.enumerated()), id: \.offset) { i, opt in
                        Text(opt).tag(i)
                    }
                }
                .pickerStyle(.menu)
                .tint(.accentGlass)

                if streamExpiryIndex == 4 {
                    HStack {
                        TextField("Minutes", text: $customExpiryMinutes)
                            .textFieldStyle(.plain)
                            .font(AppFont.body)
                            .foregroundColor(.glassForeground)
                            .frame(width: 60)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: Radius.button))
                        Text("min (5 \u{2013} 480)")
                            .font(AppFont.caption)
                            .foregroundColor(.glassForegroundSecondary)
                    }
                    .padding(.leading, Spacing.medium)
                    .onChange(of: customExpiryMinutes) { _, newValue in
                        guard let minutes = Double(newValue) else { return }
                        let clamped = max(5, min(480, minutes))
                        UserDefaults.standard.set(clamped * 60, forKey: SettingsKeys.streamExpiryOverride)
                    }
                }

                Toggle(isOn: $rememberQueue.onChange(save: SettingsKeys.rememberQueue)) {
                    Text("Remember queue on quit")
                }
                .toggleStyle(.switch)
                .tint(.accentGlass)
            }
        }
    }

    // MARK: - Discovery Card

    private var discoveryCard: some View {
        settingsCard(title: "Discovery", icon: "sparkle.magnifyingglass") {
            VStack(alignment: .leading, spacing: Spacing.tight) {
                Toggle(isOn: $discoveryOnStartup.onChange(save: SettingsKeys.discoveryOnStartup)) {
                    Text("Enable on startup")
                }
                .toggleStyle(.switch)
                .tint(.accentGlass)

                labeledSlider(
                    value: $discoveryVariety.onChange(save: SettingsKeys.discoveryVariety),
                    range: 0...100,
                    step: 1,
                    label: "Variety: \(Int(discoveryVariety))",
                    minLabel: "Similar",
                    maxLabel: "Random"
                )
            }
        }
    }

    // MARK: - Background Card

    private var backgroundCard: some View {
        settingsCard(title: "Background", icon: "photo.on.rectangle") {
            VStack(alignment: .leading, spacing: Spacing.tight) {
                Toggle(isOn: $pauseVideoOnMinimize.onChange(save: SettingsKeys.pauseVideoOnMinimize)) {
                    Text("Pause when minimized")
                }
                .toggleStyle(.switch)
                .tint(.accentGlass)

                Toggle(isOn: $pauseVideoOnStop.onChange(save: SettingsKeys.pauseVideoOnStop)) {
                    Text("Pause when stopped")
                }
                .toggleStyle(.switch)
                .tint(.accentGlass)

                Divider()
                    .overlay(Color.glassForegroundTertiary.opacity(0.15))

                Picker("Default", selection: $defaultBackgroundMode.onChange(save: SettingsKeys.defaultBackgroundMode)) {
                    ForEach(BackgroundMode.allCases, id: \.rawValue) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.menu)
                .tint(.accentGlass)

                Toggle(isOn: $fadeTransition.onChange(save: SettingsKeys.fadeTransition)) {
                    Text("Fade transitions")
                }
                .toggleStyle(.switch)
                .tint(.accentGlass)
            }
        }
    }

    // MARK: - Shortcuts Card

    private var shortcutsCard: some View {
        settingsCard(title: "Shortcuts", icon: "keyboard") {
            VStack(alignment: .leading, spacing: Spacing.micro) {
                shortcutRow("Space", "Play / Pause")
                shortcutRow("\u{2192}", "Next track")
                shortcutRow("\u{2190}", "Previous track")
                shortcutRow("\u{2191}", "Volume up")
                shortcutRow("\u{2193}", "Volume down")
                shortcutRow("S", "Toggle shuffle")
                shortcutRow("R", "Toggle repeat")
                shortcutRow("L", "Toggle discovery")
                shortcutRow("\u{2318}F", "Search")
                shortcutRow("Escape", "Close panel")
            }
        }
    }

    // MARK: - Reset

    private var resetButton: some View {
        Button("Reset to Defaults") {
            let keys: [String] = [
                SettingsKeys.crossfadeEnabled, SettingsKeys.crossfadeDuration,
                SettingsKeys.streamExpiryIndex, SettingsKeys.rememberQueue,
                SettingsKeys.discoveryOnStartup, SettingsKeys.discoveryVariety,
                SettingsKeys.pauseVideoOnMinimize, SettingsKeys.pauseVideoOnStop,
                SettingsKeys.defaultBackgroundMode, SettingsKeys.fadeTransition,
            ]
            keys.forEach { UserDefaults.standard.removeObject(forKey: $0) }
            crossfadeEnabled = false
            crossfadeDuration = 3.0
            streamExpiryIndex = 1
            rememberQueue = false
            discoveryOnStartup = false
            discoveryVariety = 50
            pauseVideoOnMinimize = true
            pauseVideoOnStop = false
            defaultBackgroundMode = .system
            fadeTransition = true
        }
        .buttonStyle(.plain)
        .font(AppFont.body)
        .foregroundColor(.glassForegroundTertiary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.tight)
        .background(.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: Radius.button))
    }

    // MARK: - Helpers

    private func labeledSlider(
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        label: String,
        minLabel: String? = nil,
        maxLabel: String? = nil
    ) -> some View {
        VStack(spacing: 2) {
            HStack {
                if let minLabel {
                    Text(minLabel)
                        .font(AppFont.small)
                        .foregroundColor(.glassForegroundTertiary)
                }
                Spacer()
                Text(label)
                    .font(AppFont.small)
                    .foregroundColor(.glassForegroundSecondary)
                Spacer()
                if let maxLabel {
                    Text(maxLabel)
                        .font(AppFont.small)
                        .foregroundColor(.glassForegroundTertiary)
                }
            }
            Slider(value: value, in: range, step: step)
                .tint(.accentGlass)
        }
    }

    private func shortcutRow(_ key: String, _ action: String) -> some View {
        HStack(spacing: Spacing.tight) {
            Text(key)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(.glassForeground)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.white.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .frame(width: 56, alignment: .leading)
            Text(action)
                .font(AppFont.body)
                .foregroundColor(.glassForegroundSecondary)
            Spacer()
        }
    }
}

private extension Binding where Value == Bool {
    func onChange(save key: String) -> Self {
        .init(
            get: { wrappedValue },
            set: { wrappedValue = $0; UserDefaults.standard.set($0, forKey: key) }
        )
    }
}

private extension Binding where Value == Int {
    func onChange(save key: String) -> Self {
        .init(
            get: { wrappedValue },
            set: { wrappedValue = $0; UserDefaults.standard.set($0, forKey: key) }
        )
    }
}

private extension Binding where Value == Double {
    func onChange(save key: String) -> Self {
        .init(
            get: { wrappedValue },
            set: { wrappedValue = $0; UserDefaults.standard.set($0, forKey: key) }
        )
    }
}

private extension Binding where Value == BackgroundMode {
    func onChange(save key: String) -> Self {
        .init(
            get: { wrappedValue },
            set: { wrappedValue = $0; UserDefaults.standard.set($0.rawValue, forKey: key) }
        )
    }
}
