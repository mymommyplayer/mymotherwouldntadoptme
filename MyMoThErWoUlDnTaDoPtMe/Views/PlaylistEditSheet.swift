import SwiftUI
import CoreData

struct PlaylistEditSheet: View {
    @Environment(\.managedObjectContext) var viewContext
    @Environment(\.dismiss) var dismiss

    let playlist: PlaylistEntity
    var playlistService: PlaylistService?

    @State private var name: String
    @State private var showFilePicker = false
    @State private var showDeleteConfirmation = false
    @State private var showError = false
    @State private var errorMessage = ""

    init(playlist: PlaylistEntity, playlistService: PlaylistService? = nil) {
        self.playlist = playlist
        self.playlistService = playlistService
        _name = State(initialValue: playlist.name)
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("Edit Playlist")
                .font(AppFont.title)

            TextField("Playlist name", text: $name)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button("Choose Background") {
                    showFilePicker = true
                }

                if let path = playlist.backgroundPath {
                    Text(URL(fileURLWithPath: path).lastPathComponent)
                        .lineLimit(1)
                }
            }

            Divider()

            Button("Delete Playlist", role: .destructive) {
                showDeleteConfirmation = true
            }

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                Button("Save") {
                    saveChanges()
                }
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding()
        .frame(width: 350)
        .fixedSize()
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.image, .mpeg4Movie, .gif]
        ) { result in
            if case .success(let url) = result {
                let copiedPath = PlaylistService.copyToContainer(url)
                if let service = playlistService {
                    try? service.updateBackground(playlist, path: copiedPath ?? url.path)
                } else {
                    playlist.backgroundPath = copiedPath ?? url.path
                    PersistenceController.saveWithAlert(context: viewContext)
                }
            }
        }
        .alert("Delete playlist?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let service = playlistService {
                    try? service.delete(playlist)
                } else {
                    viewContext.delete(playlist)
                    PersistenceController.saveWithAlert(context: viewContext)
                }
                dismiss()
            }
        } message: {
            Text("Playlist and all its tracks will be deleted.")
        }
    }

    private func saveChanges() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        if let service = playlistService {
            try? service.rename(playlist, to: trimmed)
        } else {
            playlist.name = trimmed
            PersistenceController.saveWithAlert(context: viewContext)
        }
        dismiss()
    }
}
