import Foundation
import CoreData
import Combine

@MainActor
class SearchViewModel: ObservableObject {
    @Published var query: String = ""
    @Published var homeResults: [SearchResult] = []
    @Published var isSearching = false
    @Published var parsedArtists: [String] = []
    @Published var albumsByArtist: [String: [SearchResult]] = [:]

    private var youTubeProvider: YouTubeProvider?
    private var soundCloudProvider: SoundCloudProvider?
    private var searchTask: Task<Void, Never>?
    private var searchGeneration = 0
    private var cancellables = Set<AnyCancellable>()

    init() {
        $query
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.search()
            }
            .store(in: &cancellables)
    }

    func setProviders(youTube: YouTubeProvider, soundCloud: SoundCloudProvider) {
        youTubeProvider = youTube
        soundCloudProvider = soundCloud
    }

    func search() {
        searchTask?.cancel()

        guard !query.isEmpty else {
            homeResults = []
            parsedArtists = []
            albumsByArtist = [:]
            return
        }

        searchGeneration += 1
        let gen = searchGeneration
        isSearching = true
        searchTask = Task { [weak self] in
            guard let self else { return }
            defer {
                if searchGeneration == gen { isSearching = false }
            }
            await performHomeSearch()
        }
    }

    private func performHomeSearch() async {
        let gen = searchGeneration
        let yt = youTubeProvider
        let sc = soundCloudProvider

        async let ytResults = (try? await yt?.search(query: query)) ?? []
        async let scResults = (try? await sc?.search(query: query)) ?? []

        let (ytRes, scRes) = await (ytResults, scResults)
        guard searchGeneration == gen else { return }

        var results: [SearchResult] = []
        results += ytRes
        results += scRes
        homeResults = results

        let grouped = Dictionary(grouping: results, by: { $0.artist })
        albumsByArtist = grouped
        parsedArtists = grouped.keys.sorted()
    }

    func filteredPlaylists(_ playlists: [PlaylistEntity]) -> [PlaylistEntity] {
        guard !query.isEmpty else { return playlists }
        return playlists.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    func filteredFavorites(_ favorites: [SearchResult]) -> [SearchResult] {
        guard !query.isEmpty else { return favorites }
        return favorites.filter {
            $0.title.localizedCaseInsensitiveContains(query) ||
            $0.artist.localizedCaseInsensitiveContains(query)
        }
    }
}
