import SwiftUI

@MainActor
class AppContainer: ObservableObject {
    let appState = AppState()
    let networkClient: NetworkClient
    let youTubeProvider: YouTubeProvider
    let soundCloudProvider: SoundCloudProvider
    let queueManager: QueueManager
    let audioPlayer: AudioPlayer
    let backgroundManager: BackgroundManager
    let streamExpiry: StreamExpiryManager
    let persistenceController: PersistenceController
    let searchViewModel: SearchViewModel
    let favoritesManager: FavoritesManager
    let searchHistoryManager: SearchHistoryManager
    let sleepTimerManager: SleepTimerManager
    let nowPlayingManager: NowPlayingManager
    let playlistImportService: PlaylistImportService
    let playlistService: PlaylistService
    var discoveryManager: DiscoveryManager?

    init() {
        self.streamExpiry = StreamExpiryManager()
        self.networkClient = NetworkClient.shared
        self.youTubeProvider = YouTubeProvider(networkClient: .shared)
        self.soundCloudProvider = SoundCloudProvider(networkClient: .shared)
        self.queueManager = QueueManager(streamExpiry: streamExpiry)
        self.audioPlayer = AudioPlayer()
        self.backgroundManager = BackgroundManager()
        self.persistenceController = PersistenceController.shared
        self.searchViewModel = SearchViewModel()
        self.favoritesManager = FavoritesManager()
        self.searchHistoryManager = SearchHistoryManager()
        self.sleepTimerManager = SleepTimerManager()
        self.nowPlayingManager = NowPlayingManager()
        self.playlistImportService = PlaylistImportService(networkClient: .shared)
        self.playlistService = PlaylistService(context: persistenceController.container.viewContext)

        let dm = DiscoveryManager(queueManager: queueManager)
        dm.configureSearch { [yt = youTubeProvider, sc = soundCloudProvider] query in
            async let ytResults = (try? await yt.search(query: query)) ?? []
            async let scResults = (try? await sc.search(query: query)) ?? []
            return await (ytResults + scResults)
        }
        dm.configureResolve { [yt = youTubeProvider, sc = soundCloudProvider] result in
            let provider: SourceProvider = result.source == .youtube ? yt : sc
            return try await provider.streamURL(for: result)
        }
        dm.currentTrackProvider = { [weak audioPlayer] in audioPlayer?.currentTrack }
        dm.onPlayTrack = { [weak audioPlayer, yt = youTubeProvider, sc = soundCloudProvider] track in
            Task {
                let provider: SourceProvider = track.source == .youtube ? yt : sc
                if let url = try? await provider.streamURL(for: track) {
                    audioPlayer?.play(url: url, track: track)
                }
            }
        }
        self.discoveryManager = dm

        searchViewModel.setProviders(youTube: youTubeProvider, soundCloud: soundCloudProvider)

        nowPlayingManager.setup(
            play: { [weak audioPlayer] in audioPlayer?.toggle() },
            pause: { [weak audioPlayer] in audioPlayer?.toggle() },
            next: { [weak queueManager, weak self] in
                guard let qm = queueManager else { return }
                if self?.appState.isShuffled == true {
                    let idx = Int.random(in: 0..<max(qm.items.count, 1))
                    qm.setCurrent(index: idx)
                } else {
                    qm.next()
                }
            },
            previous: { [weak queueManager] in queueManager?.previous() },
            seek: { [weak audioPlayer] in audioPlayer?.seek(to: $0) }
        )
    }
}
