import SwiftUI
import CoreData

struct AddToPlaylistPicker: View {
    @Environment(\.managedObjectContext) var viewContext
    @Environment(\.dismiss) var dismiss

    let searchResult: SearchResult
    var playlistService: PlaylistService?

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \PlaylistEntity.createdAt, ascending: true)]
    ) private var playlists: FetchedResults<PlaylistEntity>

    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        VStack(spacing: 12) {
            Text("Add to Playlist")
                .font(AppFont.title)

            Text("\(searchResult.title) — \(searchResult.artist)")
                .foregroundColor(.secondary)

            if playlists.isEmpty {
                Text("No playlists")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                List(playlists, id: \.self) { playlist in
                    Button(action: { addToPlaylist(playlist) }) {
                        HStack {
                            Text(playlist.name)
                            Spacer()
                            Text("\(playlist.tracksArray.count)")
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.plain)
            }

            Button("Cancel") { dismiss() }
        }
        .padding()
        .frame(width: 320, height: 400)
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }

    private func addToPlaylist(_ playlist: PlaylistEntity) {
        if let service = playlistService {
            do {
                try service.addTrack(searchResult, to: playlist)
                dismiss()
            } catch {
                errorMessage = "Failed to add track: \(error.localizedDescription)"
                showError = true
            }
        } else {
            let track = PlaylistTrackEntity(context: viewContext)
            track.id = UUID()
            track.index = Int64(playlist.tracksArray.count)
            track.trackID = searchResult.id
            track.title = searchResult.title
            track.artist = searchResult.artist
            track.duration = searchResult.duration
            track.source = searchResult.source.rawValue
            track.playlist = playlist

            do {
                try viewContext.save()
                dismiss()
            } catch {
                errorMessage = "Failed to add track: \(error.localizedDescription)"
                showError = true
            }
        }
    }
}
