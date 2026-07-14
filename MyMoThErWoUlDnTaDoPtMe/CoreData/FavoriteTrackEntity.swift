import CoreData

@objc(FavoriteTrackEntity)
final class FavoriteTrackEntity: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var trackID: String
    @NSManaged var title: String
    @NSManaged var artist: String
    @NSManaged var duration: Double
    @NSManaged var source: String
    @NSManaged var thumbnailURL: String?
    @NSManaged var addedAt: Date

    @nonobjc static func fetchRequest() -> NSFetchRequest<FavoriteTrackEntity> {
        NSFetchRequest<FavoriteTrackEntity>(entityName: "FavoriteTrackEntity")
    }

    var asSearchResult: SearchResult {
        let url = thumbnailURL.flatMap(URL.init)
        return SearchResult(
            id: trackID,
            title: title,
            artist: artist,
            duration: duration,
            source: SearchResult.SourceType(rawValue: source) ?? .youtube,
            thumbnailURL: url,
            streamURL: nil
        )
    }
}
