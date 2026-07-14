import Foundation

final class SavedArtistsStorage: ObservableObject {
    @Published var artists: [String] = []

    private let key = "savedArtists"

    init() {
        load()
    }

    func add(_ artist: String) {
        guard !artists.contains(artist) else { return }
        artists.append(artist)
        save()
    }

    func remove(_ artist: String) {
        artists.removeAll { $0 == artist }
        save()
    }

    private func save() {
        UserDefaults.standard.set(artists, forKey: key)
    }

    private func load() {
        artists = UserDefaults.standard.stringArray(forKey: key) ?? []
    }
}
