import Foundation

@MainActor
class FavoritesManager: ObservableObject {
    @Published var tracks: [SearchResult] = []

    private let favKey = "favorites"

    init() {
        restore()
    }

    func isFavorite(_ track: SearchResult) -> Bool {
        tracks.contains(where: { $0.id == track.id })
    }

    func toggle(_ track: SearchResult) {
        if isFavorite(track) {
            tracks.removeAll { $0.id == track.id }
        } else {
            var copy = track
            copy = SearchResult(
                id: track.id,
                title: track.title,
                artist: track.artist,
                duration: track.duration,
                source: track.source,
                thumbnailURL: track.thumbnailURL,
                streamURL: nil
            )
            tracks.append(copy)
        }
        save()
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(tracks) else { return }
        UserDefaults.standard.set(data, forKey: favKey)
    }

    private func restore() {
        guard let data = UserDefaults.standard.data(forKey: favKey),
              let saved = try? JSONDecoder().decode([SearchResult].self, from: data)
        else { return }
        tracks = saved
    }
}
