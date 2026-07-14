import CoreData
import AppKit

final class PersistenceController {
    let container: NSPersistentContainer

    static let shared: PersistenceController = {
        PersistenceController(inMemory: false)
    }()

    static var preview: PersistenceController = {
        PersistenceController(inMemory: true)
    }()

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "MyMoThErWoUlDnTaDoPtMe", managedObjectModel: Self.makeModel())

        if inMemory {
            container.persistentStoreDescriptions.first?.type = NSInMemoryStoreType
        }

        var loadError: Error?
        container.loadPersistentStores { _, error in
            loadError = error
        }

        if let error = loadError {
            let alert = NSAlert()
            alert.messageText = "Database load error"
            alert.informativeText = "The app encountered an error loading its database:\n\(error.localizedDescription)\n\nYou can reset the data (all playlists will be lost) or quit."
            alert.alertStyle = .critical
            alert.addButton(withTitle: "Reset Data")
            alert.addButton(withTitle: "Quit")
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                Self.deleteDatabaseFiles()
                container.loadPersistentStores { _, retryError in
                    if let retryError {
                        fatalError("CoreData reload failed after reset: \(retryError)")
                    }
                }
            } else {
                NSApplication.shared.terminate(nil)
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
    }

    private static func deleteDatabaseFiles() {
        let storeDescriptions = NSPersistentContainer(name: "MyMoThErWoUlDnTaDoPtMe").persistentStoreDescriptions
        for description in storeDescriptions {
            guard let url = description.url else { continue }
            let fileManager = FileManager.default
            try? fileManager.removeItem(at: url)
            let wal = url.appendingPathExtension("-wal")
            let shm = url.appendingPathExtension("-shm")
            try? fileManager.removeItem(at: wal)
            try? fileManager.removeItem(at: shm)
        }
    }

    func save() throws {
        let context = container.viewContext
        guard context.hasChanges else { return }
        try context.save()
    }

    func saveContext(_ context: NSManagedObjectContext) throws {
        guard context.hasChanges else { return }
        try context.save()
    }

    @MainActor
    static func saveWithAlert(context: NSManagedObjectContext, retryAction: (() -> Void)? = nil) {
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            let alert = NSAlert()
            alert.messageText = "Failed to save"
            alert.informativeText = "Could not save changes: \(error.localizedDescription)"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Retry")
            alert.addButton(withTitle: "Discard")
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                retryAction?()
            } else {
                context.rollback()
            }
        }
    }

    // MARK: - Model

    private static func makeModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()

        // PlaylistEntity
        let playlistEntity = NSEntityDescription()
        playlistEntity.name = "PlaylistEntity"
        playlistEntity.managedObjectClassName = "PlaylistEntity"

        let playlistID = NSAttributeDescription()
        playlistID.name = "id"
        playlistID.attributeType = .UUIDAttributeType

        let playlistName = NSAttributeDescription()
        playlistName.name = "name"
        playlistName.attributeType = .stringAttributeType

        let playlistCreatedAt = NSAttributeDescription()
        playlistCreatedAt.name = "createdAt"
        playlistCreatedAt.attributeType = .dateAttributeType

        let playlistBackgroundPath = NSAttributeDescription()
        playlistBackgroundPath.name = "backgroundPath"
        playlistBackgroundPath.attributeType = .stringAttributeType
        playlistBackgroundPath.isOptional = true

        // PlaylistTrackEntity
        let trackEntity = NSEntityDescription()
        trackEntity.name = "PlaylistTrackEntity"
        trackEntity.managedObjectClassName = "PlaylistTrackEntity"

        let trackIDAttr = NSAttributeDescription()
        trackIDAttr.name = "id"
        trackIDAttr.attributeType = .UUIDAttributeType

        let trackIndex = NSAttributeDescription()
        trackIndex.name = "index"
        trackIndex.attributeType = .integer64AttributeType

        let trackTrackID = NSAttributeDescription()
        trackTrackID.name = "trackID"
        trackTrackID.attributeType = .stringAttributeType

        let trackTitle = NSAttributeDescription()
        trackTitle.name = "title"
        trackTitle.attributeType = .stringAttributeType

        let trackArtist = NSAttributeDescription()
        trackArtist.name = "artist"
        trackArtist.attributeType = .stringAttributeType

        let trackDuration = NSAttributeDescription()
        trackDuration.name = "duration"
        trackDuration.attributeType = .doubleAttributeType

        let trackSource = NSAttributeDescription()
        trackSource.name = "source"
        trackSource.attributeType = .stringAttributeType

        let trackThumbnailURL = NSAttributeDescription()
        trackThumbnailURL.name = "thumbnailURL"
        trackThumbnailURL.attributeType = .stringAttributeType
        trackThumbnailURL.isOptional = true

        // Relationships
        let tracksRelation = NSRelationshipDescription()
        tracksRelation.name = "tracks"
        tracksRelation.destinationEntity = trackEntity
        tracksRelation.isOrdered = true
        tracksRelation.deleteRule = .cascadeDeleteRule
        tracksRelation.maxCount = 0

        let playlistRelation = NSRelationshipDescription()
        playlistRelation.name = "playlist"
        playlistRelation.destinationEntity = playlistEntity
        playlistRelation.deleteRule = .nullifyDeleteRule
        playlistRelation.maxCount = 1
        playlistRelation.isOptional = false

        tracksRelation.inverseRelationship = playlistRelation
        playlistRelation.inverseRelationship = tracksRelation

        playlistEntity.properties = [playlistID, playlistName, playlistCreatedAt, playlistBackgroundPath, tracksRelation]
        trackEntity.properties = [trackIDAttr, trackIndex, trackTrackID, trackTitle, trackArtist, trackDuration, trackSource, trackThumbnailURL, playlistRelation]

        // FavoriteTrackEntity
        let favoriteEntity = NSEntityDescription()
        favoriteEntity.name = "FavoriteTrackEntity"
        favoriteEntity.managedObjectClassName = "FavoriteTrackEntity"

        let favID = NSAttributeDescription()
        favID.name = "id"
        favID.attributeType = .UUIDAttributeType

        let favTrackID = NSAttributeDescription()
        favTrackID.name = "trackID"
        favTrackID.attributeType = .stringAttributeType

        let favTitle = NSAttributeDescription()
        favTitle.name = "title"
        favTitle.attributeType = .stringAttributeType

        let favArtist = NSAttributeDescription()
        favArtist.name = "artist"
        favArtist.attributeType = .stringAttributeType

        let favDuration = NSAttributeDescription()
        favDuration.name = "duration"
        favDuration.attributeType = .doubleAttributeType

        let favSource = NSAttributeDescription()
        favSource.name = "source"
        favSource.attributeType = .stringAttributeType

        let favThumbnailURL = NSAttributeDescription()
        favThumbnailURL.name = "thumbnailURL"
        favThumbnailURL.attributeType = .stringAttributeType
        favThumbnailURL.isOptional = true

        let favAddedAt = NSAttributeDescription()
        favAddedAt.name = "addedAt"
        favAddedAt.attributeType = .dateAttributeType

        favoriteEntity.properties = [favID, favTrackID, favTitle, favArtist, favDuration, favSource, favThumbnailURL, favAddedAt]

        model.entities = [playlistEntity, trackEntity, favoriteEntity]
        return model
    }
}
