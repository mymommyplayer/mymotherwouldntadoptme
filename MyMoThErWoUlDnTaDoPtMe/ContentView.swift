import SwiftUI
import CoreData
import UniformTypeIdentifiers
import Combine

@MainActor
enum RepeatMode: String {
    case off, repeatAll, repeatOne
}

class AppState: ObservableObject {
    @Published var isLoading = false
    @Published var error: Error?
    @Published var isShuffled = false
    @Published var repeatMode: RepeatMode = .off
}

struct ContentView: View {
    @EnvironmentObject var container: AppContainer
    private var appState: AppState { container.appState }
    @State private var discoveryRefresh = false
    @State private var discoverySpinAngle: Double = 0
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedPlaylist: PlaylistEntity?
    @State private var isControlCenterOpen = false
    @State private var focusSearch = false
    @AppStorage("hasLaunchedBefore") private var hasLaunchedBefore = false
    @State private var containerHeight: CGFloat = 600
    @State private var volume: Double = 1.0
    @State private var nowPlayingArtwork: NSImage?
    @State private var nowPlayingTrackID: String?

    private var viewContext: NSManagedObjectContext {
        container.persistenceController.container.viewContext
    }

    private let lastPlaylistKey = "lastPlaylistURI"

    var body: some View {
        ZStack {
            backgroundLayer
                .zIndex(ZLayer.video)

            scrimLayer
                .zIndex(ZLayer.scrim)

            VStack(spacing: 0) {
                ControlCenterView(
                    searchViewModel: container.searchViewModel,
                    queueManager: container.queueManager,
                    audioPlayer: container.audioPlayer,
                    favoritesManager: container.favoritesManager,
                    searchHistoryManager: container.searchHistoryManager,
                    onPlay: playSearchResult,
                    playlistImportService: container.playlistImportService,
                    playlistService: container.playlistService,
                    focusSearch: $focusSearch,
                    isControlCenterOpen: $isControlCenterOpen,
                    selectedPlaylist: $selectedPlaylist
                )
                .frame(maxHeight: containerHeight * 0.78)
                .opacity(isControlCenterOpen ? 1 : 0)
                .allowsHitTesting(isControlCenterOpen)

                NowPlayingBar(
                    audioPlayer: container.audioPlayer,
                    queueManager: container.queueManager,
                    appState: appState,
                    favoritesManager: container.favoritesManager,
                    discoveryManager: container.discoveryManager,
                    volume: $volume,
                    isControlCenterOpen: $isControlCenterOpen,
                    discoveryRefresh: $discoveryRefresh,
                    discoverySpinAngle: $discoverySpinAngle
                )
            }
            .zIndex(ZLayer.player)
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .clipped()
        .ignoresSafeArea()
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear { containerHeight = geo.size.height }
                    .onChange(of: geo.size.height) { _, h in containerHeight = h }
            }
        )
        .environment(\.managedObjectContext, container.persistenceController.container.viewContext)
        .environmentObject(appState)
        .environmentObject(container.queueManager)
        .environmentObject(container.audioPlayer)
        .modifier(KeyboardShortcutsHandler(
            audioPlayer: container.audioPlayer,
            queueManager: container.queueManager,
            appState: appState,
            discoveryManager: container.discoveryManager,
            volume: $volume,
            isControlCenterOpen: $isControlCenterOpen,
            focusSearch: $focusSearch,
            discoveryRefresh: $discoveryRefresh
        ))
        .overlay {
            if appState.isLoading { LoadingView() }
            if let error = appState.error { ErrorView(error: error, retry: { appState.error = nil }) }
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                container.backgroundManager.resume()
            case .inactive:
                break
            case .background:
                container.backgroundManager.pause()
                if UserDefaults.standard.bool(forKey: SettingsKeys.rememberQueue) {
                    container.queueManager.saveImmediately()
                }
            @unknown default: break
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willResignActiveNotification)) { _ in
            guard UserDefaults.standard.bool(forKey: SettingsKeys.pauseVideoOnMinimize) else { return }
            container.backgroundManager.pause()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            container.backgroundManager.resume()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didMiniaturizeNotification)) { _ in
            guard UserDefaults.standard.bool(forKey: SettingsKeys.pauseVideoOnMinimize) else { return }
            container.backgroundManager.pause()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didDeminiaturizeNotification)) { _ in
            container.backgroundManager.resume()
        }
        .modifier(PauseOnStopModifier(audioPlayer: container.audioPlayer, backgroundManager: container.backgroundManager))
        .onAppear {
            if !hasLaunchedBefore {
                hasLaunchedBefore = true
                isControlCenterOpen = true
            }
            restoreLastPlaylist()
            if selectedPlaylist == nil {
                applyDefaultBackgroundMode()
            }
            setupAudioPlayerEndHandler()
        }
        .onReceive(container.audioPlayer.$state) { _ in updateNowPlaying() }
        .onReceive(container.audioPlayer.$currentTime.throttle(for: 1.0, scheduler: DispatchQueue.main, latest: true)) { _ in updateNowPlaying() }
        .onReceive(NotificationCenter.default.publisher(for: .discoveryError)) { _ in
            discoveryRefresh.toggle()
        }
        .onReceive(container.queueManager.$currentIndex) { newIdx in
            guard let idx = newIdx,
                  container.queueManager.items.indices.contains(idx) else {
                container.audioPlayer.stop()
                return
            }
            let item = container.queueManager.items[idx]
            if item.state == .error {
                container.queueManager.advanceSkippingErrors()
                return
            }
            playOrResolve(item.track)
            container.discoveryManager?.trackDidStart(item.track)
        }
        .onReceive(container.queueManager.$items) { items in
            if items.isEmpty {
                container.audioPlayer.stop()
            } else if let idx = container.queueManager.currentIndex,
                      items.indices.contains(idx) {
                let item = items[idx]
                if item.state == .error {
                    container.queueManager.advanceSkippingErrors()
                    return
                }
                guard item.track.id != container.audioPlayer.currentTrack?.id else { return }
                playOrResolve(item.track)
                container.discoveryManager?.trackDidStart(item.track)
            }
        }
        .onChange(of: selectedPlaylist) { _, playlist in
            let fade = UserDefaults.standard.bool(forKey: SettingsKeys.fadeTransition)
            if let playlist {
                if fade { withAnimation(.easeInOut(duration: 0.5)) { container.backgroundManager.setForPlaylist(playlist) } }
                else { container.backgroundManager.setForPlaylist(playlist) }
                saveLastPlaylist(playlist)
            } else {
                container.backgroundManager.clear()
                UserDefaults.standard.removeObject(forKey: lastPlaylistKey)
            }
        }
    }

    // MARK: - Audio Player End Handler

    private func setupAudioPlayerEndHandler() {
        container.audioPlayer.onTrackEnd = { [weak qm = container.queueManager, weak ap = container.audioPlayer, weak np = container.nowPlayingManager, state = appState] track in
            guard let qm, let ap else { return }

            if state.repeatMode == .repeatOne {
                if let url = track.streamURL {
                    ap.play(url: url, track: track)
                } else {
                    Task {
                        let provider: SourceProvider = track.source == .youtube ? container.youTubeProvider : container.soundCloudProvider
                        if let resolved = try? await provider.streamURL(for: track) {
                            ap.play(url: resolved, track: track)
                        }
                    }
                }
                return
            }

            qm.advanceSkippingErrors()
            np?.clear()

            if qm.currentIndex == nil {
                if state.isShuffled, !qm.items.isEmpty {
                    qm.setCurrent(index: Int.random(in: 0..<qm.items.count))
                } else if state.repeatMode == .repeatAll, !qm.items.isEmpty {
                    qm.setCurrent(index: 0)
                }
            }
        }
        container.audioPlayer.onDiscoveryTrigger = nil
    }

    // MARK: - Background

    private var backgroundLayer: some View {
        BackgroundContainer(content: container.backgroundManager.background)
    }

    // MARK: - Scrim

    private var scrimLayer: some View {
        Color.black.opacity(isControlCenterOpen ? 0.65 : 0.35)
            .allowsHitTesting(false)
            .ignoresSafeArea()
    }

    // MARK: - Actions

    private func playSearchResult(_ result: SearchResult) {
        let item = QueueItem(id: result.id, track: result, source: result.source.rawValue)
        container.queueManager.add(item)

        if container.queueManager.currentIndex == nil {
            container.queueManager.setCurrent(index: container.queueManager.items.count - 1)
        }

        guard container.queueManager.currentItem?.id == item.id else { return }
        playOrResolve(result)
    }

    private func playOrResolve(_ track: SearchResult) {
        let needsRefresh = container.queueManager.needsStreamRefresh(for: track)

        if let url = track.streamURL, !needsRefresh {
            container.audioPlayer.play(url: url, track: track)
            container.queueManager.registerStream(for: track.id, url: url)
        } else {
            Task {
                do {
                    let provider: SourceProvider = track.source == .youtube
                        ? container.youTubeProvider : container.soundCloudProvider
                    let resolved = try await provider.streamURL(for: track)
                    container.audioPlayer.play(url: resolved, track: track)
                    container.queueManager.registerStream(for: track.id, url: resolved)
                } catch {
                    if let idx = container.queueManager.items.firstIndex(where: { $0.track.id == track.id }) {
                        container.queueManager.setError(on: idx)
                    }
                    container.queueManager.advanceSkippingErrors()
                }
            }
        }
    }

    // MARK: - Now Playing

    private func updateNowPlaying() {
        guard let track = container.audioPlayer.currentTrack else {
            nowPlayingTrackID = nil
            nowPlayingArtwork = nil
            container.nowPlayingManager.clear()
            return
        }

        if nowPlayingTrackID != track.id {
            nowPlayingTrackID = track.id
            nowPlayingArtwork = nil
            prefetchArtwork(for: track)
        }

        container.nowPlayingManager.updateNowPlaying(
            track: track,
            duration: container.audioPlayer.duration,
            currentTime: container.audioPlayer.currentTime,
            rate: container.audioPlayer.state == .playing ? 1.0 : 0.0,
            artwork: nowPlayingArtwork
        )
    }

    private func prefetchArtwork(for track: SearchResult) {
        guard let url = track.thumbnailURL else { return }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data, let image = NSImage(data: data) else { return }
            Task { @MainActor in
                nowPlayingArtwork = image
                updateNowPlaying()
            }
        }.resume()
    }

    // MARK: - Persistence

    private func saveLastPlaylist(_ playlist: PlaylistEntity) {
        guard let uri = playlist.objectID.uriRepresentation().absoluteString.data(using: .utf8) else { return }
        UserDefaults.standard.set(uri, forKey: lastPlaylistKey)
        UserDefaults.standard.set(uri, forKey: SettingsKeys.lastBackgroundPlaylistURI)
    }

    private func restoreLastPlaylist() {
        guard let data = UserDefaults.standard.data(forKey: lastPlaylistKey),
              let uriString = String(data: data, encoding: .utf8),
              let uri = URL(string: uriString) else { return }
        let coordinator = container.persistenceController.container.persistentStoreCoordinator
        guard let objectID = coordinator.managedObjectID(forURIRepresentation: uri),
              let playlist = try? viewContext.existingObject(with: objectID) as? PlaylistEntity else { return }
        selectedPlaylist = playlist
    }

    private func applyDefaultBackgroundMode() {
        if UserDefaults.standard.object(forKey: "defaultBackgroundIndex") != nil,
           UserDefaults.standard.object(forKey: SettingsKeys.defaultBackgroundMode) == nil {
            let oldIndex = UserDefaults.standard.integer(forKey: "defaultBackgroundIndex")
            let migrated: BackgroundMode = oldIndex == 0 ? .system : oldIndex == 1 ? .lastUsed : .random
            UserDefaults.standard.set(migrated.rawValue, forKey: SettingsKeys.defaultBackgroundMode)
            UserDefaults.standard.removeObject(forKey: "defaultBackgroundIndex")
        }
        let raw = UserDefaults.standard.string(forKey: SettingsKeys.defaultBackgroundMode)
            ?? BackgroundMode.system.rawValue
        let mode = BackgroundMode(rawValue: raw) ?? .system
        switch mode {
        case .system:
            container.backgroundManager.setDefaultVideo()
        case .lastUsed:
            restoreBackgroundFromLastPlaylist()
        case .random:
            setRandomPlaylistBackground()
        }
    }

    private func restoreBackgroundFromLastPlaylist() {
        guard let data = UserDefaults.standard.data(forKey: SettingsKeys.lastBackgroundPlaylistURI),
              let uriString = String(data: data, encoding: .utf8),
              let uri = URL(string: uriString) else { return }
        let coordinator = container.persistenceController.container.persistentStoreCoordinator
        guard let objectID = coordinator.managedObjectID(forURIRepresentation: uri),
              let playlist = try? viewContext.existingObject(with: objectID) as? PlaylistEntity else { return }
        container.backgroundManager.setForPlaylist(playlist)
    }

    private func setRandomPlaylistBackground() {
        let request = PlaylistEntity.fetchRequest()
        guard let playlists = try? viewContext.fetch(request) else { return }
        let withBackground = playlists.filter { ($0.backgroundPath ?? "").isEmpty == false }
        guard let picked = withBackground.randomElement() else { return }
        container.backgroundManager.setForPlaylist(picked)
    }
}

// MARK: - Overlay Views

struct LoadingView: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
            VStack(spacing: Spacing.tight) {
                ProgressView()
                    .scaleEffect(0.5)
                Text("Loading\u{2026}")
                    .font(AppFont.caption)
                    .foregroundColor(.glassForegroundSecondary)
            }
        }
    }
}

struct ErrorView: View {
    let error: Error
    let retry: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
            VStack(spacing: Spacing.medium) {
                Image(systemName: "exclamationmark.triangle")
                    .font(AppFont.largeIcon)
                    .foregroundColor(.glassForegroundSecondary)
                Text(error.localizedDescription)
                    .font(AppFont.body)
                    .foregroundColor(.glassForegroundSecondary)
                    .multilineTextAlignment(.center)
                Button("Retry", action: retry)
                    .font(AppFont.body)
            }
        }
    }
}

private struct PauseOnStopModifier: ViewModifier {
    let audioPlayer: AudioPlayer
    let backgroundManager: BackgroundManager

    func body(content: Content) -> some View {
        content
            .onChange(of: audioPlayer.state) { _, state in
                guard UserDefaults.standard.bool(forKey: SettingsKeys.pauseVideoOnStop) else { return }
                switch state {
                case .paused, .stopped:
                    backgroundManager.pause()
                case .playing:
                    backgroundManager.resume()
                default: break
                }
            }
    }
}
