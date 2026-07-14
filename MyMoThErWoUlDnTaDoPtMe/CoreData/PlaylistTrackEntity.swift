import CoreData

@objc(PlaylistTrackEntity)
final class PlaylistTrackEntity: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var index: Int64
    @NSManaged var trackID: String
    @NSManaged var title: String
    @NSManaged var artist: String
    @NSManaged var duration: Double
    @NSManaged var source: String
    @NSManaged var thumbnailURL: String?
    @NSManaged var playlist: PlaylistEntity?

    @nonobjc static func fetchRequest() -> NSFetchRequest<PlaylistTrackEntity> {
        NSFetchRequest<PlaylistTrackEntity>(entityName: "PlaylistTrackEntity")
    }
}
