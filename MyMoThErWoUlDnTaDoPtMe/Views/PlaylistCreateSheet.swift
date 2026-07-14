import SwiftUI
import CoreData
import AppKit

struct PlaylistCreateSheet: View {
    @Environment(\.managedObjectContext) var viewContext
    @Environment(\.dismiss) var dismiss

    let onCreated: (PlaylistEntity) -> Void
    let importService: PlaylistImportService?
    let playlistService: PlaylistService?

    init(importService: PlaylistImportService? = nil, playlistService: PlaylistService? = nil, onCreated: @escaping (PlaylistEntity) -> Void) {
        self.importService = importService
        self.playlistService = playlistService
        self.onCreated = onCreated
    }

    @State private var name = ""
    @State private var backgroundURL: URL?
    @State private var showFilePicker = false
    @State private var selectedMethod: CreateMethod = .manual
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var importURL = ""
    @State private var importSource: ImportSource = .youtube
    @State private var isImporting = false
    @State private var importTask: Task<Void, Never>?

    enum CreateMethod: String, CaseIterable {
        case manual = "Create Manually"
        case `import` = "Import from YouTube/SoundCloud"
    }

    enum ImportSource: String, CaseIterable {
        case youtube = "YouTube"
        case soundcloud = "SoundCloud"
    }

    var body: some View {
        VStack(spacing: 16) {
            Picker("Method", selection: $selectedMethod) {
                ForEach(CreateMethod.allCases, id: \.self) { method in
                    Text(method.rawValue).tag(method)
                }
            }
            .pickerStyle(.radioGroup)

            switch selectedMethod {
            case .manual:
                manualCreateView
            case .import:
                importView
            }
        }
        .padding()
        .frame(width: 400)
        .fixedSize()
        .onDisappear {
            importTask?.cancel()
        }
    }

    private var manualCreateView: some View {
        VStack(spacing: 12) {
            TextField("Playlist name", text: $name)
                .textFieldStyle(.roundedBorder)

            HStack {
                if let backgroundURL {
                    Text(backgroundURL.lastPathComponent)
                        .lineLimit(1)
                }
                Button("Choose Background") {
                    showFilePicker = true
                }
            }

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                Button("Create") {
                    createPlaylist()
                }
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.image, .mpeg4Movie, .gif]
        ) { result in
            if case .success(let url) = result {
                backgroundURL = url
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }

    private var importView: some View {
        VStack(spacing: 12) {
            Text("Import Playlist")
                .font(AppFont.title)

            Picker("Source", selection: $importSource) {
                ForEach(ImportSource.allCases, id: \.self) { source in
                    Text(source.rawValue).tag(source)
                }
            }
            .pickerStyle(.segmented)

            TextField("Playlist URL", text: $importURL)
                .textFieldStyle(.roundedBorder)
                .disabled(isImporting)

            if isImporting {
                ProgressView("Importing...")
                    .frame(maxWidth: .infinity)
            }

            HStack {
                Button("Cancel") {
                    importTask?.cancel()
                    dismiss()
                }
                Button("Import") {
                    startImport()
                }
                .disabled(importURL.trimmingCharacters(in: .whitespaces).isEmpty || isImporting || importService == nil)
            }
        }
        .alert("Import Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }

    private func startImport() {
        guard let service = importService else {
            errorMessage = "Import service not configured"
            showError = true
            return
        }

        isImporting = true
        errorMessage = ""

        importTask = Task {
            defer {
                Task { @MainActor in
                    isImporting = false
                }
            }

            do {
                let playlist: PlaylistEntity
                switch importSource {
                case .youtube:
                    playlist = try await service.importFromYouTube(url: importURL, context: viewContext)
                case .soundcloud:
                    playlist = try await service.importFromSoundCloud(url: importURL, context: viewContext)
                }

                await MainActor.run {
                    onCreated(playlist)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    viewContext.rollback()
                    if let importError = error as? PlaylistImportError {
                        errorMessage = importError.localizedDescription
                    } else if let appError = error as? AppError {
                        errorMessage = appError.localizedDescription
                    } else {
                        errorMessage = error.localizedDescription
                    }
                    showError = true
                }
            }
        }
    }

    private func createPlaylist() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        let backgroundPath = backgroundURL.flatMap { PlaylistService.copyToContainer($0) } ?? backgroundURL?.path

        do {
            let playlist: PlaylistEntity
            if let service = playlistService {
                playlist = try service.create(name: trimmed, backgroundPath: backgroundPath)
            } else {
                let p = PlaylistEntity(context: viewContext)
                p.id = UUID()
                p.name = trimmed
                p.createdAt = Date()
                p.backgroundPath = backgroundPath
                try viewContext.save()
                playlist = p
            }
            onCreated(playlist)
            dismiss()
        } catch {
            let alert = NSAlert()
            alert.messageText = "Failed to create playlist"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
}
