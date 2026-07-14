import SwiftUI

struct NowPlayingBar: View {
    @ObservedObject var audioPlayer: AudioPlayer
    @ObservedObject var queueManager: QueueManager
    @ObservedObject var appState: AppState
    @ObservedObject var favoritesManager: FavoritesManager
    let discoveryManager: DiscoveryManager?
    @Binding var volume: Double
    @Binding var isControlCenterOpen: Bool
    @Binding var discoveryRefresh: Bool
    @Binding var discoverySpinAngle: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            playerBar
            progressBar
            controlsBar
        }
    }

    // MARK: - Player Bar (discovery error)

    @ViewBuilder
    private var playerBar: some View {
        if let err = discoveryManager?.lastError, !err.isEmpty {
            Text(err)
                .font(AppFont.small)
                .foregroundColor(.red.opacity(0.8))
                .lineLimit(1)
                .padding(.horizontal, Spacing.wide)
        }
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(.white.opacity(0.15))
                    .frame(height: 2)

                Rectangle()
                    .fill(.white.opacity(0.5))
                    .frame(width: geo.size.width * progressFraction, height: 2)

                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onEnded { v in
                                let w = geo.size.width
                                let fraction = w > 0 ? max(0, min(1, v.location.x / w)) : 0
                                let time = Double(fraction) * audioPlayer.duration
                                audioPlayer.seek(to: time)
                            }
                    )
            }
        }
        .frame(height: 8)
        .padding(.horizontal, Spacing.wide)
    }

    private var progressFraction: CGFloat {
        guard audioPlayer.duration > 0 else { return 0 }
        return min(1, CGFloat(audioPlayer.currentTime / audioPlayer.duration))
    }

    // MARK: - Controls Bar

    private var controlsBar: some View {
        HStack(spacing: 0) {
            if let currentItem = queueManager.currentItem {
                HStack(spacing: Spacing.tight) {
                    ArtworkView(url: currentItem.track.thumbnailURL, size: 32)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(currentItem.track.title)
                            .font(AppFont.body)
                            .foregroundColor(.glassForeground)
                            .lineLimit(1)
                        Text(currentItem.track.artist)
                            .font(AppFont.caption)
                            .foregroundColor(.glassForegroundSecondary)
                            .lineLimit(1)
                    }
                }
            } else {
                Text("\u{2014} / \u{2014}")
                    .font(AppFont.body)
                    .foregroundColor(.glassForegroundTertiary)
            }

            Spacer()

            HStack(spacing: Spacing.medium) {
                volumeButton
                shuffleButton
                prevButton
                playPauseButton
                nextButton
                repeatButton
                favoriteButton
                controlCenterButton
                discoveryButton
            }
        }
        .padding(.horizontal, Spacing.wide)
        .padding(.vertical, Spacing.tight)
    }

    // MARK: - Transport Buttons

    private var volumeButton: some View {
        HStack(spacing: Spacing.tight) {
            Button {
                volume = volume > 0 ? 0 : 1
                audioPlayer.setVolume(Float(volume))
            } label: {
                let icon: String = {
                    if volume == 0 { return "speaker.slash.fill" }
                    if volume < 0.33 { return "speaker.wave.1.fill" }
                    if volume < 0.66 { return "speaker.wave.2.fill" }
                    return "speaker.wave.3.fill"
                }()
                Image(systemName: icon)
                    .font(AppFont.smallIcon)
                    .foregroundColor(volume > 0 ? .glassForeground : .glassForegroundTertiary)
                    .frame(minWidth: PanelSize.hitArea, minHeight: PanelSize.hitArea)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressFeedback())
            .help("Toggle mute")
            .accessibilityLabel("Volume")

            Color.clear
                .frame(width: 50, height: 14)
                .overlay(
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(.white.opacity(0.15))
                                .frame(height: 3)
                            Capsule()
                                .fill(.white.opacity(0.4))
                                .frame(width: geo.size.width * CGFloat(volume), height: 3)
                        }
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { v in
                                    let val = max(0, min(1, Double(v.location.x / geo.size.width)))
                                    volume = val
                                    audioPlayer.setVolume(Float(val))
                                }
                        )
                        .offset(y: 6)
                    }
                )
        }
    }

    private var shuffleButton: some View {
        Button { appState.isShuffled.toggle() } label: {
            Image(systemName: "shuffle")
                .font(AppFont.smallIcon)
                .foregroundColor(appState.isShuffled ? .accentGlass : .glassForegroundTertiary)
                .frame(minWidth: PanelSize.hitArea, minHeight: PanelSize.hitArea)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressFeedback())
        .help("Toggle shuffle")
        .accessibilityLabel("Shuffle")
    }

    private var prevButton: some View {
        Button { queueManager.previous() } label: {
            Image(systemName: "backward.fill")
                .font(AppFont.mediumIcon)
                .foregroundColor(.glassForeground)
                .frame(minWidth: PanelSize.hitArea, minHeight: PanelSize.hitArea)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressFeedback())
        .help("Previous track")
        .accessibilityLabel("Previous track")
    }

    private var playPauseButton: some View {
        Button { audioPlayer.toggle() } label: {
            Image(systemName: audioPlayer.state == .playing ? "pause.fill" : "play.fill")
                .font(AppFont.largeIcon)
                .foregroundColor(.glassForeground)
                .frame(minWidth: PanelSize.primaryHitArea, minHeight: PanelSize.primaryHitArea)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressFeedback())
        .help(audioPlayer.state == .playing ? "Pause" : "Play")
        .accessibilityLabel(audioPlayer.state == .playing ? "Pause" : "Play")
    }

    private var nextButton: some View {
        Button {
            if appState.isShuffled {
                let randomIdx = Int.random(in: 0..<max(queueManager.items.count, 1))
                queueManager.setCurrent(index: randomIdx)
            } else if appState.repeatMode == .repeatAll {
                queueManager.nextRepeatAll()
            } else {
                queueManager.next()
            }
        } label: {
            Image(systemName: "forward.fill")
                .font(AppFont.mediumIcon)
                .foregroundColor(.glassForeground)
                .frame(minWidth: PanelSize.hitArea, minHeight: PanelSize.hitArea)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressFeedback())
        .help("Next track")
        .accessibilityLabel("Next track")
    }

    private var repeatButton: some View {
        Button {
            switch appState.repeatMode {
            case .off: appState.repeatMode = .repeatAll
            case .repeatAll: appState.repeatMode = .repeatOne
            case .repeatOne: appState.repeatMode = .off
            }
        } label: {
            let icon: String = {
                switch appState.repeatMode {
                case .off: return "repeat"
                case .repeatAll: return "repeat"
                case .repeatOne: return "repeat.1"
                }
            }()
            let isOn = appState.repeatMode != .off
            Image(systemName: icon)
                .font(AppFont.smallIcon)
                .foregroundColor(isOn ? .accentGlass : .glassForegroundTertiary)
                .frame(minWidth: PanelSize.hitArea, minHeight: PanelSize.hitArea)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressFeedback())
        .help("Toggle repeat")
        .accessibilityLabel("Repeat")
    }

    private var controlCenterButton: some View {
        Button {
            if reduceMotion {
                isControlCenterOpen.toggle()
            } else {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                    isControlCenterOpen.toggle()
                }
            }
        } label: {
            Image(systemName: isControlCenterOpen ? "chevron.down" : "chevron.up")
                .font(AppFont.smallIcon)
                .foregroundColor(isControlCenterOpen ? .accentGlass : .glassForeground)
                .frame(minWidth: PanelSize.hitArea, minHeight: PanelSize.hitArea)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressFeedback())
        .help("Toggle control center")
        .accessibilityLabel("Toggle control center")
    }

    private var favoriteButton: some View {
        Button {
            if let track = queueManager.currentItem?.track {
                favoritesManager.toggle(track)
            }
        } label: {
            let isFav = queueManager.currentItem.map { favoritesManager.isFavorite($0.track) } ?? false
            Image(systemName: isFav ? "heart.fill" : "heart")
                .font(AppFont.smallIcon)
                .foregroundColor(isFav ? .accentGlass : .glassForegroundTertiary)
                .frame(minWidth: PanelSize.hitArea, minHeight: PanelSize.hitArea)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressFeedback())
        .help("Toggle favorite")
        .accessibilityLabel("Toggle favorite")
    }

    private var discoveryButton: some View {
        let _ = discoveryRefresh
        let err = discoveryManager?.lastError
        let isOn = discoveryManager?.isEnabled ?? false
        return Button {
            if NSEvent.modifierFlags.contains(.option) {
                if let track = audioPlayer.currentTrack {
                    discoveryManager?.forceDiscovery(for: track)
                }
            } else {
                let wasEnabled = discoveryManager?.isEnabled ?? false
                discoveryManager?.toggle()
                if !wasEnabled, let track = audioPlayer.currentTrack {
                    discoveryManager?.trackDidStart(track)
                }
            }
            discoveryRefresh.toggle()
        } label: {
            Image(systemName: "sparkle")
                .font(AppFont.smallIcon)
                .rotationEffect(.degrees(isOn ? discoverySpinAngle : 0))
                .foregroundColor(err != nil ? .red : (isOn ? .accentGlass : .glassForegroundTertiary))
                .frame(minWidth: PanelSize.hitArea, minHeight: PanelSize.hitArea)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressFeedback())
        .help(err ?? "Discovery mode")
        .accessibilityLabel("Discovery mode")
        .accessibilityHint(err ?? "Auto-play similar tracks. Option+click to force now.")
        .onReceive(Timer.publish(every: 1.0 / 60, on: .main, in: .common).autoconnect()) { _ in
            if discoveryManager?.isSearching == true {
                discoverySpinAngle += 6
                if discoverySpinAngle >= 360 { discoverySpinAngle -= 360 }
            } else if discoverySpinAngle != 0 {
                discoverySpinAngle = 0
            }
        }
    }
}
