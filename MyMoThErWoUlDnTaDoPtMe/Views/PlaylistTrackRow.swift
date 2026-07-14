import SwiftUI
import CoreData
import UniformTypeIdentifiers

struct PlaylistTrackRow: View {
    let track: PlaylistTrackEntity
    let onRemove: () -> Void
    var onPlay: ((SearchResult) -> Void)?
    var queueManager: QueueManager?
    var favoritesManager: FavoritesManager?

    var body: some View {
        HStack(spacing: Spacing.tight) {
            let thumbnailURL = track.thumbnailURL.flatMap(URL.init)
            ArtworkView(url: thumbnailURL, size: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .lineLimit(1)
                Text(track.artist)
                    .lineLimit(1)
                    .font(AppFont.caption)
                    .foregroundColor(.glassForegroundSecondary)
            }
            Spacer()
            Text(formatDuration(track.duration))
                .font(AppFont.caption)
                .monospacedDigit()
                .foregroundColor(.glassForegroundSecondary)
        }
        .padding(.vertical, 4)
        .contextMenu {
            let url = track.thumbnailURL.flatMap(URL.init)
            let trackResult = SearchResult(
                id: track.trackID,
                title: track.title,
                artist: track.artist,
                duration: track.duration,
                source: SearchResult.SourceType(rawValue: track.source) ?? .youtube,
                thumbnailURL: url,
                streamURL: nil
            )
            Button("Play now") { onPlay?(trackResult) }
            if let qm = queueManager {
                Button("Play next") {
                    let item = QueueItem(id: trackResult.id, track: trackResult, source: trackResult.source.rawValue)
                    qm.insertAfterCurrent(item)
                }
                Button("Add to queue") {
                    qm.add(QueueItem(id: trackResult.id, track: trackResult, source: trackResult.source.rawValue))
                }
            }
            if let fm = favoritesManager {
                Button(fm.isFavorite(trackResult) ? "Remove from favorites" : "Add to favorites") {
                    fm.toggle(trackResult)
                }
            }
            Divider()
            Button("Remove from Playlist", role: .destructive) {
                onRemove()
            }
        }
        .help("Drag to queue or reorder")
        .onDrag {
            let data = DraggedTrack(
                trackID: track.trackID,
                title: track.title,
                artist: track.artist,
                duration: track.duration,
                source: track.source,
                thumbnailURL: track.thumbnailURL
            )
            guard let encoded = try? JSONEncoder().encode(data) else {
                return NSItemProvider()
            }
            let provider = NSItemProvider(item: encoded as NSData, typeIdentifier: NSPasteboard.PasteboardType.playlistTrack.rawValue)
            provider.suggestedName = track.title
            return provider
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
