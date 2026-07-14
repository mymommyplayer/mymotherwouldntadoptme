import SwiftUI

struct QueuePanelView: View {
    @ObservedObject var queueManager: QueueManager
    @State private var dragIndex: Int?

    var body: some View {
        VStack(spacing: 0) {
            queueToolbar
            queueList
        }
        .frame(maxHeight: .infinity)
        .padding(.bottom, Spacing.medium)
    }

    private var queueToolbar: some View {
        HStack {
            Text("Queue")
                .font(AppFont.caption)
                .foregroundColor(.glassForegroundTertiary)

            Spacer()

            Button {
                queueManager.clear()
            } label: {
                Image(systemName: "trash")
                    .font(AppFont.smallIcon)
                    .foregroundColor(.glassForegroundTertiary)
                    .frame(minWidth: PanelSize.hitArea, minHeight: PanelSize.hitArea)
            }
            .buttonStyle(.plain)
            .help("Clear queue")
            .accessibilityLabel("Clear queue")
        }
        .padding(.horizontal, Spacing.tight)
        .padding(.vertical, Spacing.tight)
    }

    private var queueList: some View {
        let qm = queueManager
        return ScrollView {
            if qm.items.isEmpty {
                EmptyStateView(
                    icon: "music.note.list",
                    title: "Queue is empty",
                    subtitle: "Add tracks from search or playlists."
                )
                .padding(.top, 40)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(qm.items.enumerated()), id: \.element.id) { index, item in
                        queueItemRow(index: index, item: item)
                            .opacity(dragIndex == index ? 0.4 : 1)
                            .onDrag {
                                dragIndex = index
                                return NSItemProvider(object: item.id as NSString)
                            }
                            .onDrop(
                                of: [.text],
                                delegate: QueueDropDelegate(
                                    queueManager: qm,
                                    index: index,
                                    dragIndex: $dragIndex
                                )
                            )
                        if index < qm.items.count - 1 {
                            Color.clear
                                .frame(height: 1)
                                .background(Color.glassForegroundTertiary.opacity(0.1))
                        }
                    }
                }
            }
        }
        .onDrop(of: [NSPasteboard.PasteboardType.playlistTrack.rawValue], isTargeted: nil) { providers -> Bool in
            guard let provider = providers.first else { return false }
            provider.loadItem(forTypeIdentifier: NSPasteboard.PasteboardType.playlistTrack.rawValue, options: nil) { item, _ in
                guard let data = item as? Data else { return }
                if let tracks = try? JSONDecoder().decode([DraggedTrack].self, from: data) {
                    Task { @MainActor in
                        for dragged in tracks {
                            let url = dragged.thumbnailURL.flatMap(URL.init)
                            let track = SearchResult(
                                id: dragged.trackID,
                                title: dragged.title,
                                artist: dragged.artist,
                                duration: dragged.duration,
                                source: SearchResult.SourceType(rawValue: dragged.source) ?? .youtube,
                                thumbnailURL: url,
                                streamURL: nil
                            )
                            qm.add(QueueItem(id: dragged.trackID, track: track, source: dragged.source))
                        }
                    }
                } else if let dragged = try? JSONDecoder().decode(DraggedTrack.self, from: data) {
                    let url = dragged.thumbnailURL.flatMap(URL.init)
                    let track = SearchResult(
                        id: dragged.trackID,
                        title: dragged.title,
                        artist: dragged.artist,
                        duration: dragged.duration,
                        source: SearchResult.SourceType(rawValue: dragged.source) ?? .youtube,
                        thumbnailURL: url,
                        streamURL: nil
                    )
                    Task { @MainActor in
                        qm.add(QueueItem(id: dragged.trackID, track: track, source: dragged.source))
                    }
                }
            }
            return true
        }
    }

    private func queueItemRow(index: Int, item: QueueItem) -> some View {
        HStack(spacing: Spacing.tight) {
            ArtworkView(url: item.track.thumbnailURL, size: 28)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 1) {
                Text(item.track.title)
                    .font(AppFont.body)
                    .foregroundColor(index == queueManager.currentIndex ? .accentGlass : .glassForeground)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(item.track.artist)
                    .font(AppFont.caption)
                    .foregroundColor(.glassForegroundSecondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)

            Text(formattedDuration(item.track.duration))
                .font(AppFont.small)
                .monospacedDigit()
                .foregroundColor(.glassForegroundTertiary)
                .layoutPriority(1)

            Button {
                queueManager.remove(at: index)
            } label: {
                Image(systemName: "xmark")
                    .font(AppFont.smallIcon)
                    .foregroundColor(.glassForegroundTertiary)
                    .frame(minWidth: 24, minHeight: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .layoutPriority(1)
        }
        .padding(.horizontal, Spacing.tight)
        .padding(.vertical, Spacing.tight)
    }

    private func formattedDuration(_ duration: TimeInterval) -> String {
        let m = Int(duration) / 60
        let s = Int(duration) % 60
        return "\(m):\(String(format: "%02d", s))"
    }
}

struct QueueDropDelegate: DropDelegate {
    let queueManager: QueueManager
    let index: Int
    @Binding var dragIndex: Int?

    func performDrop(info: DropInfo) -> Bool {
        defer { dragIndex = nil }
        guard let from = dragIndex, from != index else { return false }
        queueManager.move(from: IndexSet(integer: from), to: index > from ? index + 1 : index)
        return true
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func dropExited(info: DropInfo) {
        dragIndex = nil
    }
}
