import CoreData

@objc(PlaylistEntity)
final class PlaylistEntity: NSManagedObject, Identifiable {
    @NSManaged var id: UUID
    @NSManaged var name: String
    @NSManaged var createdAt: Date
    @NSManaged var backgroundPath: String?
    @NSManaged var tracks: NSOrderedSet?

    @nonobjc static func fetchRequest() -> NSFetchRequest<PlaylistEntity> {
        NSFetchRequest<PlaylistEntity>(entityName: "PlaylistEntity")
    }

    var tracksArray: [PlaylistTrackEntity] {
        tracks?.array as? [PlaylistTrackEntity] ?? []
    }
}
