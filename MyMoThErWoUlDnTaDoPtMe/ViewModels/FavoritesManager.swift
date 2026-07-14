import Foundation
import CoreData

@MainActor
class FavoritesManager: ObservableObject {
    @Published var tracks: [SearchResult] = []

    private let context: NSManagedObjectContext
    private let favKey = "favorites"

    init(context: NSManagedObjectContext = PersistenceController.shared.container.viewContext) {
        self.context = context
        migrateIfNeeded()
        restore()
    }

    func isFavorite(_ track: SearchResult) -> Bool {
        tracks.contains(where: { $0.id == track.id })
    }

    func toggle(_ track: SearchResult) {
        if isFavorite(track) {
            remove(track)
        } else {
            add(track)
        }
    }

    private func add(_ track: SearchResult) {
        let entity = FavoriteTrackEntity(context: context)
        entity.id = UUID()
        entity.trackID = track.id
        entity.title = track.title
        entity.artist = track.artist
        entity.duration = track.duration
        entity.source = track.source.rawValue
        entity.thumbnailURL = track.thumbnailURL?.absoluteString
        entity.addedAt = Date()
        save()
        tracks.append(track)
    }

    private func remove(_ track: SearchResult) {
        let request = FavoriteTrackEntity.fetchRequest()
        request.predicate = NSPredicate(format: "trackID == %@", track.id)
        if let entity = try? context.fetch(request).first {
            context.delete(entity)
            save()
        }
        tracks.removeAll { $0.id == track.id }
    }

    private func save() {
        guard context.hasChanges else { return }
        try? context.save()
    }

    private func restore() {
        let request = FavoriteTrackEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "addedAt", ascending: false)]
        guard let entities = try? context.fetch(request) else { return }
        tracks = entities.map { $0.asSearchResult }
    }

    private func migrateIfNeeded() {
        guard let data = UserDefaults.standard.data(forKey: favKey),
              let saved = try? JSONDecoder().decode([SearchResult].self, from: data),
              !saved.isEmpty else { return }

        let request = FavoriteTrackEntity.fetchRequest()
        guard (try? context.count(for: request)) == 0 else {
            UserDefaults.standard.removeObject(forKey: favKey)
            return
        }

        for track in saved {
            let entity = FavoriteTrackEntity(context: context)
            entity.id = UUID()
            entity.trackID = track.id
            entity.title = track.title
            entity.artist = track.artist
            entity.duration = track.duration
            entity.source = track.source.rawValue
            entity.thumbnailURL = track.thumbnailURL?.absoluteString
            entity.addedAt = Date()
        }
        try? context.save()
        UserDefaults.standard.removeObject(forKey: favKey)
    }
}
