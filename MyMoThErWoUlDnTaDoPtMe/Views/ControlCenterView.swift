import SwiftUI
import CoreData
import UniformTypeIdentifiers

enum SearchFilter: String, CaseIterable {
    case artists = "Artists"
    case tracks = "Tracks"

    var icon: String {
        switch self {
        case .artists: "person.2"
        case .tracks: "music.note"
        }
    }
}

enum ControlSection: String, CaseIterable {
    case playlists = "Playlists"
    case favorites = "Favorites"
    case artists = "Artists"

    var icon: String {
        switch self {
        case .playlists: "list.bullet"
        case .favorites: "heart"
        case .artists: "person.2"
        }
    }
}

@MainActor
struct ControlCenterView: View {
    @ObservedObject var searchViewModel: SearchViewModel
    @ObservedObject var queueManager: QueueManager
    @ObservedObject var audioPlayer: AudioPlayer
    @ObservedObject var favoritesManager: FavoritesManager
    var searchHistoryManager: SearchHistoryManager?
    var onPlay: ((SearchResult) -> Void)?
    var playlistImportService: PlaylistImportService?
    var playlistService: PlaylistService?
    @Binding var focusSearch: Bool
    @Binding var isControlCenterOpen: Bool
    @Binding var selectedPlaylist: PlaylistEntity?
    @Environment(\.managedObjectContext) var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \PlaylistEntity.createdAt, ascending: true)]
    ) private var playlists: FetchedResults<PlaylistEntity>

    @State private var selectedSection: ControlSection? = .playlists
    @AppStorage("lastSelectedSection") private var lastSelectedSectionRaw: String = ControlSection.playlists.rawValue
    @State private var showAddToPlaylist: SearchResult?
    @State private var showCreateSheet = false
    @State private var showFilePicker = false
    @State private var playlistForFilePicker: PlaylistEntity?
    @State private var showSettingsContent = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isSearchActive = false
    @FocusState private var searchFocused: Bool
    @State private var editingPlaylist: PlaylistEntity?
    @State private var confirmDeletePlaylist: PlaylistEntity?
    @State private var searchFilter: SearchFilter = .tracks
    @State private var expandedArtist: String?
    @StateObject private var savedArtistsStorage = SavedArtistsStorage()

    var body: some View {
        VStack(spacing: 0) {
            TopCapsuleView()
                .padding(.top, Spacing.tight)

            headerBar
            bodyContent
                .frame(maxHeight: .infinity)
        }
        .onChange(of: focusSearch) { _, newValue in
            if newValue {
                searchFocused = true
                showSettingsContent = false
                focusSearch = false
            }
        }
        .onChange(of: searchViewModel.query) { _, query in
            if !query.isEmpty {
                isSearchActive = true
            }
        }
        .onChange(of: isControlCenterOpen) { _, open in
            if !open { searchFocused = false }
        }
        .onChange(of: selectedSection) { _, section in
            if let section { lastSelectedSectionRaw = section.rawValue }
        }
        .onAppear {
            if selectedSection == nil, !isSearchActive {
                selectedSection = ControlSection(rawValue: lastSelectedSectionRaw) ?? .playlists
            }
        }
        .sheet(item: $showAddToPlaylist) { result in
            AddToPlaylistPicker(searchResult: result, playlistService: playlistService)
        }
        .sheet(isPresented: $showCreateSheet) {
            PlaylistCreateSheet(importService: playlistImportService, playlistService: playlistService) { _ in
                selectedSection = .playlists
            }
        }
        .sheet(item: $editingPlaylist) { playlist in
            PlaylistTrackListView(
                playlist: playlist,
                favoritesManager: favoritesManager,
                queueManager: queueManager,
                playlistService: playlistService,
                onPlay: onPlay
            )
        }
        .alert("Delete playlist?", isPresented: .init(
            get: { confirmDeletePlaylist != nil },
            set: { if !$0 { confirmDeletePlaylist = nil } }
        )) {
            Button("Delete", role: .destructive) { deletePlaylist() }
            Button("Cancel", role: .cancel) { confirmDeletePlaylist = nil }
        } message: {
            Text("This action cannot be undone.")
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.image, .mpeg4Movie, .gif]
        ) { result in
            switch result {
            case .success(let url):
                let copiedPath = PlaylistService.copyToContainer(url)
                editingPlaylist?.backgroundPath = copiedPath ?? url.path
                PersistenceController.saveWithAlert(context: viewContext)
                if let playlist = editingPlaylist, playlist == selectedPlaylist {
                    selectedPlaylist = playlist
                }
            case .failure(let error):
                errorMessage = error.localizedDescription
                showError = true
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: Spacing.medium) {
                SearchField(text: $searchViewModel.query, placeholder: "Search YouTube, SoundCloud\u{2026}", onCommit: {
                    if isSearchActive, let first = searchViewModel.homeResults.first {
                        onPlay?(first)
                    } else {
                        isSearchActive = true
                        searchViewModel.search()
                        if let manager = searchHistoryManager {
                            manager.add(searchViewModel.query)
                        }
                    }
                }, isFocused: $searchFocused)
                    .font(AppFont.body)
                    .foregroundColor(.glassForeground)
                    .padding(.horizontal, Spacing.medium)
                    .frame(height: 32)
                    .background(.white.opacity(0.1))
                    .cornerRadius(Radius.button)
            }

            if searchFocused, searchViewModel.query.isEmpty, let manager = searchHistoryManager, !manager.recentSearches.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Spacing.tight) {
                        ForEach(manager.recentSearches.prefix(8), id: \.self) { query in
                            Button {
                                searchViewModel.query = query
                                searchViewModel.search()
                                manager.add(query)
                            } label: {
                                Text(query)
                                    .font(AppFont.small)
                                    .foregroundColor(.glassForegroundSecondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(.white.opacity(0.08))
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, Spacing.tight)
                }
            }
        }
        .padding(.horizontal, Spacing.wide)
        .padding(.vertical, Spacing.tight)
    }

    // MARK: - Body

    private var bodyContent: some View {
        HStack(spacing: 0) {
            leftSidebar
            centerContent
            QueuePanelView(queueManager: queueManager)
                .frame(width: 220)
                .overlay(alignment: .leading) {
                    Rectangle()
                        .fill(Color.glassForegroundTertiary.opacity(0.15))
                        .frame(width: 1)
                        .padding(.bottom, Spacing.micro)
                }
        }
    }

    // MARK: - Left Sidebar

    private var leftSidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(ControlSection.allCases, id: \.self) { section in
                    navItem(section)
                }
            }
            .padding(.vertical, Spacing.tight)

            Spacer()

            navItemSettings
                .padding(.bottom, Spacing.micro)
        }
        .frame(maxWidth: 160, maxHeight: .infinity)
    }

    private func navItem(_ section: ControlSection) -> some View {
        Button {
            selectedSection = section
            showSettingsContent = false
            isSearchActive = false
        } label: {
            HStack(spacing: Spacing.tight) {
                Image(systemName: section.icon)
                    .font(AppFont.smallIcon)
                    .foregroundColor(selectedSection == section ? .accentGlass : .glassForegroundSecondary)
                    .frame(width: 20)
                Text(section.rawValue)
                    .font(AppFont.body)
                    .foregroundColor(selectedSection == section ? .glassForeground : .glassForegroundSecondary)
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, Spacing.tight)
            .padding(.vertical, 6)
            .background(
                selectedSection == section ? Color.glassHighlight : Color.clear,
                in: RoundedRectangle(cornerRadius: Radius.button)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
    }

    private var navItemSettings: some View {
        Button {
            showSettingsContent = true
            selectedSection = nil
            isSearchActive = false
        } label: {
            HStack(spacing: Spacing.tight) {
                Image(systemName: "gearshape")
                    .font(AppFont.smallIcon)
                    .foregroundColor(showSettingsContent ? .accentGlass : .glassForegroundTertiary)
                    .frame(width: 20)
                Text("Settings")
                    .font(AppFont.body)
                    .foregroundColor(showSettingsContent ? .glassForeground : .glassForegroundTertiary)
                Spacer()
            }
            .padding(.horizontal, Spacing.tight)
            .padding(.vertical, 6)
            .background(showSettingsContent ? Color.glassHighlight : Color.clear, in: RoundedRectangle(cornerRadius: Radius.button))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
    }

    // MARK: - Center Content

    private var centerContent: some View {
        Group {
            if showSettingsContent {
                SettingsView()
            } else if isSearchActive && !searchViewModel.query.isEmpty {
                searchResultsView
            } else {
                sectionContentView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Spacing.wide)
    }

    @ViewBuilder
    private var sectionContentView: some View {
        if let section = selectedSection {
            switch section {
            case .playlists:
                playlistsContentView
            case .favorites:
                favoritesContentView
            case .artists:
                artistsContentView
            }
        }
    }

    // MARK: - Playlists Content

    private var playlistsContentView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.medium) {
                HStack {
                    Text("Playlists")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.glassForeground)
                    Spacer()
                    Button {
                        showCreateSheet = true
                    } label: {
                        Label("Create New", systemImage: "plus")
                            .font(AppFont.body)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.accentGlass)
                }

                if playlists.isEmpty {
                    EmptyStateView(
                        icon: "music.note.list",
                        title: "No playlists yet",
                        subtitle: "Tap \"Create New\" to get started."
                    )
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 140, maximum: 200))], spacing: Spacing.tight) {
                        ForEach(playlists, id: \.self) { playlist in
                            playlistCard(playlist)
                        }
                    }
                }
            }
        }
    }

    private func playlistCard(_ playlist: PlaylistEntity) -> some View {
        VStack(spacing: Spacing.tight) {
            RoundedRectangle(cornerRadius: Radius.panel)
                .fill(Color.glassHighlight)
                .overlay {
                    VStack(spacing: 4) {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 24))
                            .foregroundColor(.glassForegroundTertiary)
                        Text("\(playlist.tracksArray.count) tracks")
                            .font(AppFont.caption)
                            .foregroundColor(.glassForegroundTertiary)
                    }
                }
                .aspectRatio(1, contentMode: .fit)

            Text(playlist.name)
                .font(AppFont.body)
                .foregroundColor(.glassForeground)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            editingPlaylist = playlist
            selectedPlaylist = playlist
        }
        .help("Drag to queue")
        .onDrag {
            let data = try? JSONEncoder().encode(playlist.tracksArray.map { track in
                DraggedTrack(
                    trackID: track.trackID,
                    title: track.title,
                    artist: track.artist,
                    duration: track.duration,
                    source: track.source,
                    thumbnailURL: track.thumbnailURL
                )
            })
            let provider = NSItemProvider(item: data as NSData?, typeIdentifier: NSPasteboard.PasteboardType.playlistTrack.rawValue)
            provider.suggestedName = playlist.name
            return provider
        }
        .contextMenu {
            Button("Open") {
                editingPlaylist = playlist
                selectedPlaylist = playlist
            }
            Button("Background") {
                editingPlaylist = playlist
                selectedPlaylist = playlist
                showFilePicker = true
            }
            if !playlist.tracksArray.isEmpty {
                Button("Add to Queue") { addPlaylistToQueue(playlist) }
                Divider()
                Button("Export as JSON") { exportPlaylist(playlist, format: .json) }
                Button("Export as M3U") { exportPlaylist(playlist, format: .m3u) }
            }
            Divider()
            Button("Delete", role: .destructive) { confirmDeletePlaylist = playlist }
        }
    }

    private func deletePlaylist() {
        guard let playlist = confirmDeletePlaylist else { return }
        editingPlaylist = nil
        confirmDeletePlaylist = nil
        DispatchQueue.main.async {
            if let service = self.playlistService {
                try? service.delete(playlist)
            } else {
                self.viewContext.delete(playlist)
                PersistenceController.saveWithAlert(context: self.viewContext)
            }
        }
    }

    // MARK: - Favorites Content

    private var favoritesContentView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.medium) {
                HStack {
                    Text("Tracks")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.glassForeground)
                    Spacer()
                    if !favoritesManager.tracks.isEmpty {
                        Button {
                            for track in favoritesManager.tracks {
                                queueManager.add(QueueItem(id: UUID().uuidString, track: track, source: track.source.rawValue))
                            }
                        } label: {
                            Label("Add to Queue", systemImage: "text.badge.plus")
                                .font(AppFont.body)
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.accentGlass)
                    }
                }

                if favoritesManager.tracks.isEmpty {
                    EmptyStateView(
                        icon: "heart",
                        title: "No favorites yet",
                        subtitle: "Tap the heart on any track to add it here."
                    )
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(favoritesManager.tracks) { track in
                            trackRow(track)
                            if track.id != favoritesManager.tracks.last?.id {
                                Divider()
                                    .background(Color.glassForegroundTertiary.opacity(0.15))
                            }
                        }
                    }
                    .background(.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: Radius.panel))
                }
            }
        }
    }

    private func trackRow(_ track: SearchResult) -> some View {
        HStack(spacing: Spacing.tight) {
            ArtworkView(url: track.thumbnailURL, size: 28)

            VStack(alignment: .leading, spacing: 1) {
                Text(track.title)
                    .font(AppFont.body)
                    .foregroundColor(.glassForeground)
                    .lineLimit(1)
                Text(track.artist)
                    .font(AppFont.caption)
                    .foregroundColor(.glassForegroundSecondary)
                    .lineLimit(1)
            }

            Spacer()

            Button {
                onPlay?(track)
            } label: {
                Image(systemName: "play.fill")
                    .font(AppFont.smallIcon)
                    .foregroundColor(.glassForeground)
                    .frame(minWidth: PanelSize.hitArea, minHeight: PanelSize.hitArea)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Spacing.medium)
        .padding(.vertical, Spacing.tight)
        .contextMenu {
            Button("Play now") { onPlay?(track) }
            Button("Play next") {
                let item = QueueItem(id: track.id, track: track, source: track.source.rawValue)
                queueManager.insertAfterCurrent(item)
            }
            Button("Add to queue") {
                queueManager.add(QueueItem(id: track.id, track: track, source: track.source.rawValue))
            }
            Button(favoritesManager.isFavorite(track) ? "Remove from favorites" : "Add to favorites") {
                favoritesManager.toggle(track)
            }
            if !playlists.isEmpty {
                Divider()
                ForEach(playlists.prefix(5), id: \.self) { pl in
                    Button(pl.name) {
                        addToPlaylist(track: track, playlist: pl)
                    }
                }
                Divider()
                Button("Add to Playlist\u{2026}") { showAddToPlaylist = track }
            }
        }
    }

    // MARK: - Artists Content

    private var artistsContentView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.medium) {
                if !isSearchActive, !savedArtistsStorage.artists.isEmpty {
                    Text("Saved Artists")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.glassForeground)

                    LazyVStack(spacing: 0) {
                        ForEach(savedArtistsStorage.artists, id: \.self) { artist in
                            HStack(spacing: Spacing.tight) {
                                Image(systemName: "person.circle")
                                    .font(.system(size: 24))
                                    .foregroundColor(.glassForegroundSecondary)
                                    .frame(width: 32, height: 32)

                                VStack(alignment: .leading, spacing: 1) {
                                    Text(artist)
                                        .font(AppFont.body)
                                        .foregroundColor(.glassForeground)
                                        .lineLimit(1)
                                }

                                Spacer()

                                Button {
                                    savedArtistsStorage.remove(artist)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(AppFont.smallIcon)
                                        .foregroundColor(.glassForegroundTertiary)
                                        .frame(minWidth: PanelSize.hitArea, minHeight: PanelSize.hitArea)
                                }
                                .buttonStyle(.plain)

                                Button {
                                    searchViewModel.query = artist
                                    searchViewModel.search()
                                    isSearchActive = true
                                } label: {
                                    Image(systemName: "magnifyingglass")
                                        .font(AppFont.smallIcon)
                                        .foregroundColor(.glassForegroundSecondary)
                                        .frame(minWidth: PanelSize.hitArea, minHeight: PanelSize.hitArea)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, Spacing.medium)
                            .padding(.vertical, Spacing.tight)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                searchViewModel.query = artist
                                searchViewModel.search()
                                isSearchActive = true
                            }

                            if artist != savedArtistsStorage.artists.last {
                                Divider()
                                    .background(Color.glassForegroundTertiary.opacity(0.15))
                            }
                        }
                    }
                    .background(.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: Radius.panel))

                }

                if isSearchActive && !searchViewModel.parsedArtists.isEmpty {
                    LazyVStack(spacing: 0) {
                        ForEach(searchViewModel.parsedArtists, id: \.self) { artist in
                            artistRow(artist)
                            if artist != searchViewModel.parsedArtists.last {
                                Divider()
                                    .background(Color.glassForegroundTertiary.opacity(0.15))
                            }
                        }
                    }
                    .background(.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: Radius.panel))
                }
            }
        }
    }

    private func artistRow(_ artist: String) -> some View {
        let isExpanded = expandedArtist == artist
        let tracks = searchViewModel.albumsByArtist[artist] ?? []

        return VStack(spacing: 0) {
            HStack(spacing: Spacing.tight) {
                Image(systemName: "person.circle")
                    .font(.system(size: 24))
                    .foregroundColor(.glassForegroundSecondary)
                    .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 1) {
                    Text(artist)
                        .font(AppFont.body)
                        .foregroundColor(.glassForeground)
                        .lineLimit(1)
                    Text("\(tracks.count) tracks")
                        .font(AppFont.caption)
                        .foregroundColor(.glassForegroundSecondary)
                        .lineLimit(1)
                }

                Spacer()

                Button {
                    if savedArtistsStorage.artists.contains(artist) {
                        savedArtistsStorage.remove(artist)
                    } else {
                        savedArtistsStorage.add(artist)
                    }
                } label: {
                    Image(systemName: savedArtistsStorage.artists.contains(artist) ? "heart.fill" : "heart")
                        .font(AppFont.smallIcon)
                        .foregroundColor(savedArtistsStorage.artists.contains(artist) ? .accentGlass : .glassForegroundTertiary)
                        .frame(minWidth: PanelSize.hitArea, minHeight: PanelSize.hitArea)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(AppFont.smallIcon)
                    .foregroundColor(.glassForegroundTertiary)

                Button {
                    guard let first = tracks.first else { return }
                    for track in tracks {
                        queueManager.add(QueueItem(id: track.id, track: track, source: track.source.rawValue))
                    }
                    queueManager.setCurrent(index: max(queueManager.items.count - tracks.count, 0))
                    onPlay?(first)
                } label: {
                    Image(systemName: "play.fill")
                        .font(AppFont.smallIcon)
                        .foregroundColor(.glassForeground)
                        .frame(minWidth: PanelSize.hitArea, minHeight: PanelSize.hitArea)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, Spacing.medium)
            .padding(.vertical, Spacing.tight)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.2)) {
                    expandedArtist = isExpanded ? nil : artist
                }
            }
            .contextMenu {
                Button(savedArtistsStorage.artists.contains(artist) ? "Remove from saved" : "Save artist") {
                    if savedArtistsStorage.artists.contains(artist) {
                        savedArtistsStorage.remove(artist)
                    } else {
                        savedArtistsStorage.add(artist)
                    }
                }
                Button("Add to Queue") {
                    guard let tracks = searchViewModel.albumsByArtist[artist] else { return }
                    for track in tracks {
                        queueManager.add(QueueItem(id: track.id, track: track, source: track.source.rawValue))
                    }
                }
                if !playlists.isEmpty {
                    Divider()
                    ForEach(playlists.prefix(5), id: \.self) { pl in
                        Button("\(pl.name) — all tracks") {
                            addArtistTracksToPlaylist(artist: artist, playlist: pl)
                        }
                    }
                }
            }

            if isExpanded {
                ForEach(tracks) { track in
                    HStack(spacing: Spacing.tight) {
                        ArtworkView(url: track.thumbnailURL, size: 28)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(track.title)
                                .font(AppFont.body)
                                .foregroundColor(.glassForeground)
                                .lineLimit(1)
                            Text(formattedDuration(track.duration))
                                .font(AppFont.caption)
                                .monospacedDigit()
                                .foregroundColor(.glassForegroundSecondary)
                        }

                        Spacer()

                        Button {
                            onPlay?(track)
                        } label: {
                            Image(systemName: "play.fill")
                                .font(AppFont.smallIcon)
                                .foregroundColor(.glassForeground)
                                .frame(minWidth: PanelSize.hitArea, minHeight: PanelSize.hitArea)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, Spacing.wide)
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                    .onTapGesture { onPlay?(track) }

                    if track.id != tracks.last?.id {
                        Divider()
                            .background(Color.glassForegroundTertiary.opacity(0.15))
                            .padding(.leading, Spacing.wide)
                    }
                }
            }
        }
    }

    private func addPlaylistToQueue(_ playlist: PlaylistEntity) {
        for track in playlist.tracksArray {
            let result = SearchResult.from(entity: track)
            queueManager.add(QueueItem(id: result.id, track: result, source: result.source.rawValue))
        }
    }

    private enum ExportFormat {
        case json, m3u
    }

    private func exportPlaylist(_ playlist: PlaylistEntity, format: ExportFormat) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "\(playlist.name).\(format == .json ? "json" : "m3u")"
        panel.allowedContentTypes = format == .json ? [.json] : [.plainText]
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            let service = playlistService ?? PlaylistService(context: viewContext)
            let data: Data? = format == .json ? service.exportAsJSON(playlist) : service.exportAsM3U(playlist).data(using: .utf8)
            if let data {
                try? data.write(to: url)
            }
        }
    }

    private func addArtistTracksToPlaylist(artist: String, playlist: PlaylistEntity) {
        let tracks = searchViewModel.albumsByArtist[artist] ?? []
        for track in tracks {
            addToPlaylist(track: track, playlist: playlist)
        }
    }

    private func addAllFavoritesToPlaylist(_ playlist: PlaylistEntity) {
        for track in favoritesManager.tracks {
            addToPlaylist(track: track, playlist: playlist)
        }
    }

    private func addToPlaylist(track: SearchResult, playlist: PlaylistEntity) {
        if let service = playlistService {
            try? service.addTrack(track, to: playlist)
        } else {
            let trackEntity = PlaylistTrackEntity(context: viewContext)
            trackEntity.id = UUID()
            trackEntity.index = Int64(playlist.tracksArray.count)
            trackEntity.trackID = track.id
            trackEntity.title = track.title
            trackEntity.artist = track.artist
            trackEntity.duration = track.duration
            trackEntity.source = track.source.rawValue
            trackEntity.thumbnailURL = track.thumbnailURL?.absoluteString
            trackEntity.playlist = playlist
            PersistenceController.saveWithAlert(context: viewContext)
        }
    }

    private func formattedDuration(_ duration: TimeInterval) -> String {
        let m = Int(duration) / 60
        let s = Int(duration) % 60
        return "\(m):\(String(format: "%02d", s))"
    }

    // MARK: - Search Results

    private var searchResultsView: some View {
        VStack(spacing: 0) {
            if !searchViewModel.homeResults.isEmpty {
                HStack(spacing: Spacing.tight) {
                    ForEach(SearchFilter.allCases, id: \.self) { filter in
                        Button {
                            searchFilter = filter
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: filter.icon)
                                    .font(AppFont.small)
                                Text(filter.rawValue)
                                    .font(AppFont.caption)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(searchFilter == filter ? Color.glassHighlight : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: Radius.button))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, Spacing.wide)
                .padding(.vertical, Spacing.tight)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.medium) {
                    if searchViewModel.isSearching {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Spacing.huge)
                    } else if searchViewModel.homeResults.isEmpty {
                        if searchViewModel.query.isEmpty {
                            EmptyStateView(
                                icon: "magnifyingglass",
                                title: "Start by searching for music",
                                subtitle: "Try searching for \"Daft Punk\" or \"Radiohead\""
                            )
                        } else {
                            EmptyStateView(
                                icon: "magnifyingglass",
                                title: "Nothing found",
                                subtitle: "Try a different search query."
                            )
                        }
                    } else {
                        let showArtists = searchFilter == .artists
                        let showTracks = searchFilter == .tracks

                        if showArtists, !searchViewModel.parsedArtists.isEmpty {
                            Text("Artists")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.glassForeground)

                            LazyVStack(spacing: 0) {
                                ForEach(searchViewModel.parsedArtists, id: \.self) { artist in
                                    artistRow(artist)
                                    if artist != searchViewModel.parsedArtists.last {
                                        Divider()
                                            .background(Color.glassForegroundTertiary.opacity(0.15))
                                    }
                                }
                            }
                            .background(.white.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: Radius.panel))
                        }

                        if showTracks {
                            Text("Tracks")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.glassForeground)

                            LazyVStack(spacing: 0) {
                                ForEach(searchViewModel.homeResults) { result in
                                    searchResultRow(result)
                                    if result.id != searchViewModel.homeResults.last?.id {
                                        Divider()
                                            .background(Color.glassForegroundTertiary.opacity(0.15))
                                    }
                                }
                            }
                            .background(.white.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: Radius.panel))
                        }
                    }
                }
            }
        }
    }

    private func searchResultRow(_ result: SearchResult) -> some View {
        HStack(spacing: Spacing.tight) {
            ArtworkView(url: result.thumbnailURL, size: 28)
            VStack(alignment: .leading, spacing: 1) {
                Text(result.title)
                    .font(AppFont.body)
                    .foregroundColor(.glassForeground)
                    .lineLimit(1)
                Text(result.artist)
                    .font(AppFont.caption)
                    .foregroundColor(.glassForegroundSecondary)
                    .lineLimit(1)
            }

            Spacer()

            Text(result.source == .youtube ? "YT" : "SC")
                .font(AppFont.small)
                .foregroundColor(.glassForegroundTertiary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.white.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 4))

            Button {
                onPlay?(result)
            } label: {
                Image(systemName: "play.fill")
                    .font(AppFont.smallIcon)
                    .foregroundColor(.glassForeground)
                    .frame(minWidth: PanelSize.hitArea, minHeight: PanelSize.hitArea)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                showAddToPlaylist = result
            } label: {
                Image(systemName: "plus.circle")
                    .font(AppFont.smallIcon)
                    .foregroundColor(.glassForegroundSecondary)
                    .frame(minWidth: PanelSize.hitArea, minHeight: PanelSize.hitArea)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Spacing.medium)
        .padding(.vertical, Spacing.tight)
        .contentShape(Rectangle())
        .onTapGesture { onPlay?(result) }
        .contextMenu {
            Button("Play now") { onPlay?(result) }
            Button("Play next") {
                let item = QueueItem(id: result.id, track: result, source: result.source.rawValue)
                queueManager.insertAfterCurrent(item)
            }
            Button("Add to queue") {
                queueManager.add(QueueItem(id: result.id, track: result, source: result.source.rawValue))
            }
            Button(favoritesManager.isFavorite(result) ? "Remove from favorites" : "Add to favorites") {
                favoritesManager.toggle(result)
            }
            if !playlists.isEmpty {
                Divider()
                ForEach(playlists.prefix(5), id: \.self) { pl in
                    Button(pl.name) {
                        addToPlaylist(track: result, playlist: pl)
                    }
                }
                Divider()
            }
            Button("Add to Playlist\u{2026}") { showAddToPlaylist = result }
        }
    }

}
