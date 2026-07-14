import SwiftUI
import CoreData
import UniformTypeIdentifiers

struct PlaylistTrackListView: View {
    @Environment(\.managedObjectContext) var viewContext

    let playlist: PlaylistEntity
    var favoritesManager: FavoritesManager?
    var queueManager: QueueManager?
    var playlistService: PlaylistService?
    var onPlay: ((SearchResult) -> Void)?

    @FetchRequest
    private var tracks: FetchedResults<PlaylistTrackEntity>

    @State private var showAddFromFavorites = false
    @State private var showFilePicker = false
    @State private var showEditSheet = false

    init(
        playlist: PlaylistEntity,
        favoritesManager: FavoritesManager? = nil,
        queueManager: QueueManager? = nil,
        playlistService: PlaylistService? = nil,
        onPlay: ((SearchResult) -> Void)? = nil
    ) {
        self.playlist = playlist
        self.favoritesManager = favoritesManager
        self.queueManager = queueManager
        self.playlistService = playlistService
        self.onPlay = onPlay
        _tracks = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \PlaylistTrackEntity.index, ascending: true)],
            predicate: NSPredicate(format: "playlist == %@", playlist),
            animation: .default
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(playlist.name)
                    .font(.title)
                Spacer()
                Text("\(tracks.count) tracks")
                    .foregroundColor(.secondary)
                Button {
                    showEditSheet = true
                } label: {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.plain)
                .help("Edit playlist")
            }
            .padding()

            Divider()

            if tracks.isEmpty {
                EmptyStateView(
                    icon: "music.note.list",
                    title: "No tracks yet",
                    subtitle: "Add tracks from your favorites."
                )
                .frame(maxHeight: .infinity)
            } else {
                List {
                    ForEach(tracks, id: \.id) { track in
                        PlaylistTrackRow(
                            track: track,
                            onRemove: { removeTrack(track) },
                            onPlay: onPlay,
                            queueManager: queueManager,
                            favoritesManager: favoritesManager
                        )
                        .contextMenu {
                            let trackResult = self.searchResult(from: track)
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
                            Button("Delete", role: .destructive) {
                                removeTrack(track)
                            }
                        }
                    }
                    .onDelete(perform: deleteTracks)
                    .onMove(perform: moveTrack)
                }
                .listStyle(.plain)
            }

            Divider()

            HStack(spacing: 8) {
                Button(action: { showAddFromFavorites = true }) {
                    Label("From Favorites", systemImage: "heart")
                        .font(AppFont.body)
                }
                .buttonStyle(.plain)

                Spacer()

                Button(action: { showFilePicker = true }) {
                    Image(systemName: "photo")
                        .font(AppFont.body)
                }
                .buttonStyle(.plain)

                if !tracks.isEmpty {
                    Button(action: playAll) {
                        Image(systemName: "play.fill")
                            .font(AppFont.body)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.accentGlass)

                    Button(action: addAllToQueue) {
                        Image(systemName: "text.insert")
                            .font(AppFont.body)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Spacing.medium)
            .padding(.vertical, Spacing.tight)
        }
        .sheet(isPresented: $showAddFromFavorites) {
            FavoritesPickerSheet(
                favorites: favoritesManager?.tracks ?? [],
                onAdd: { tracks in
                    for track in tracks {
                        addTrackFromSearchResult(track)
                    }
                }
            )
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.image, .mpeg4Movie, .gif]
        ) { result in
            switch result {
            case .success(let url):
                let copiedPath = PlaylistService.copyToContainer(url)
                if let service = playlistService {
                    try? service.updateBackground(playlist, path: copiedPath ?? url.path)
                } else {
                    playlist.backgroundPath = copiedPath ?? url.path
                    PersistenceController.saveWithAlert(context: viewContext)
                }
            case .failure(let error):
                break
            }
        }
        .sheet(isPresented: $showEditSheet) {
            PlaylistEditSheet(playlist: playlist, playlistService: playlistService)
                .environment(\.managedObjectContext, viewContext)
        }
    }

    private func removeTrack(_ track: PlaylistTrackEntity) {
        if let service = playlistService {
            try? service.removeTrack(track)
        } else {
            viewContext.delete(track)
            PersistenceController.saveWithAlert(context: viewContext)
        }
    }

    private func deleteTracks(at offsets: IndexSet) {
        if let service = playlistService {
            try? service.removeTracks(at: offsets, from: tracks)
        } else {
            for idx in offsets {
                let track = tracks[idx]
                viewContext.delete(track)
            }
            PersistenceController.saveWithAlert(context: viewContext)
        }
    }

    private func moveTrack(from source: IndexSet, to destination: Int) {
        if let service = playlistService {
            try? service.moveTracks(from: source, to: destination, tracks: tracks)
        } else {
            var ordered = tracks.map { $0 }
            ordered.move(fromOffsets: source, toOffset: destination)
            for (i, track) in ordered.enumerated() {
                track.index = Int64(i)
            }
            PersistenceController.saveWithAlert(context: viewContext)
        }
    }

    private func addTrackFromSearchResult(_ result: SearchResult) {
        if let service = playlistService {
            try? service.addTrack(result, to: playlist, index: tracks.count)
        } else {
            let track = PlaylistTrackEntity(context: viewContext)
            track.id = UUID()
            track.index = Int64(tracks.count)
            track.trackID = result.id
            track.title = result.title
            track.artist = result.artist
            track.duration = result.duration
            track.source = result.source.rawValue
            track.thumbnailURL = result.thumbnailURL?.absoluteString
            track.playlist = playlist
            PersistenceController.saveWithAlert(context: viewContext)
        }
    }

    private func allAsSearchResults() -> [SearchResult] {
        tracks.map { SearchResult.from(entity: $0) }
    }

    private func playAll() {
        let results = allAsSearchResults()
        guard let first = results.first else { return }
        for result in results {
            queueManager?.add(QueueItem(id: result.id, track: result, source: result.source.rawValue))
        }
        queueManager?.setCurrent(index: max((queueManager?.items.count ?? 0) - results.count, 0))
        onPlay?(first)
    }

    private func addAllToQueue() {
        for result in allAsSearchResults() {
            queueManager?.add(QueueItem(id: result.id, track: result, source: result.source.rawValue))
        }
    }

    private func searchResult(from entity: PlaylistTrackEntity) -> SearchResult {
        SearchResult.from(entity: entity)
    }
}

struct FavoritesPickerSheet: View {
    @Environment(\.dismiss) var dismiss

    let favorites: [SearchResult]
    let onAdd: ([SearchResult]) -> Void

    @State private var selected: Set<String> = []

    var body: some View {
        VStack(spacing: 12) {
            Text("Add from Favorites")
                .font(AppFont.title)

            if favorites.isEmpty {
                Text("No favorite tracks")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                List(favorites, id: \.id) { track in
                    HStack(spacing: 8) {
                        ArtworkView(url: track.thumbnailURL, size: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(track.title)
                                .font(AppFont.body)
                                .lineLimit(1)
                            Text(track.artist)
                                .font(AppFont.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        if selected.contains(track.id) {
                            Image(systemName: "checkmark")
                                .foregroundColor(.accentGlass)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if selected.contains(track.id) {
                            selected.remove(track.id)
                        } else {
                            selected.insert(track.id)
                        }
                    }
                }
            }

            Divider()

            HStack {
                Button("Select All") {
                    selected = Set(favorites.map(\.id))
                }
                .disabled(favorites.isEmpty)

                Button("Deselect All") {
                    selected.removeAll()
                }
                .disabled(selected.isEmpty)

                Spacer()

                Button("Cancel") { dismiss() }

                Button("Add (\(selected.count))") {
                    let tracks = favorites.filter { selected.contains($0.id) }
                    onAdd(tracks)
                    dismiss()
                }
                .disabled(selected.isEmpty)
            }
            .padding()
        }
        .padding()
        .frame(width: 400, height: 500)
        .fixedSize()
    }
}
