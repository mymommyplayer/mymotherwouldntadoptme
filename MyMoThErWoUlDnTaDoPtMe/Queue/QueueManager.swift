import Foundation

@MainActor
class QueueManager: ObservableObject, QueueManagerProtocol {
    @Published private(set) var items: [QueueItem] = []
    @Published private(set) var currentIndex: Int?
    private var streamExpiry: StreamExpiryManager
    private let queueKey = "savedQueue"
    private let indexKey = "savedQueueIndex"

    init(streamExpiry: StreamExpiryManager = StreamExpiryManager()) {
        self.streamExpiry = streamExpiry
        restoreQueue()
    }

    func saveImmediately() {
        persist()
    }

    private func persist() {
        guard UserDefaults.standard.bool(forKey: SettingsKeys.rememberQueue) else { return }
        guard let data = try? JSONEncoder().encode(items) else { return }
        UserDefaults.standard.set(data, forKey: queueKey)
        UserDefaults.standard.set(currentIndex, forKey: indexKey)
    }

    private func restoreQueue() {
        guard UserDefaults.standard.bool(forKey: SettingsKeys.rememberQueue) else { return }
        guard let data = UserDefaults.standard.data(forKey: queueKey),
              let saved = try? JSONDecoder().decode([QueueItem].self, from: data) else { return }
        items = saved
        let savedIndex = UserDefaults.standard.integer(forKey: indexKey)
        currentIndex = items.indices.contains(savedIndex) ? savedIndex : nil
    }

    var currentItem: QueueItem? {
        guard let index = currentIndex else { return nil }
        return items[safe: index]
    }

    func add(_ item: QueueItem) {
        if let id = item.track.streamURL?.absoluteString {
            streamExpiry.registerStream(for: id)
        }
        items.append(item)
        persist()
    }

    func needsStreamRefresh(for item: QueueItem) -> Bool {
        guard let url = item.track.streamURL?.absoluteString else { return true }
        return streamExpiry.isStreamExpired(for: url)
    }

    func remove(at index: Int) {
        guard items.indices.contains(index) else { return }
        let item = items[index]
        if let url = item.track.streamURL?.absoluteString {
            streamExpiry.removeStream(for: url)
        }
        items.remove(at: index)
        if let current = currentIndex {
            if index < current {
                currentIndex = current - 1
            } else if index == current {
                if items.isEmpty {
                    currentIndex = nil
                } else {
                    currentIndex = min(current, items.count - 1)
                }
            }
        }
        persist()
    }

    func move(from source: IndexSet, to destination: Int) {
        let currentID = currentItem?.id
        items.move(fromOffsets: source, toOffset: destination)
        if let currentID {
            currentIndex = items.firstIndex(where: { $0.id == currentID })
        }
        persist()
    }

    func next() {
        guard !items.isEmpty else { currentIndex = nil; return }
        if let current = currentIndex {
            if current + 1 < items.count {
                currentIndex = current + 1
            } else {
                currentIndex = nil
            }
        } else {
            currentIndex = 0
        }
    }

    func nextRepeatAll() {
        guard !items.isEmpty else { currentIndex = nil; return }
        let next = ((currentIndex ?? -1) + 1) % items.count
        currentIndex = next
    }

    func previous() {
        guard !items.isEmpty else { return }
        currentIndex = max((currentIndex ?? 0) - 1, 0)
    }

    func setCurrent(index: Int) {
        guard items.indices.contains(index) else { return }
        currentIndex = index
    }

    func advance() {
        guard let idx = currentIndex else { return }
        if idx + 1 < items.count { currentIndex = idx + 1 }
        else { currentIndex = nil }
        persist()
    }

    func removeFinished() {
        guard let idx = currentIndex else { return }
        items.remove(at: idx)
        if items.isEmpty { currentIndex = nil }
        else { currentIndex = min(idx, items.count - 1) }
        persist()
    }

    func insertAfterCurrent(_ item: QueueItem) {
        if let id = item.track.streamURL?.absoluteString {
            streamExpiry.registerStream(for: id)
        }
        let insertIndex = (currentIndex ?? items.count - 1) + 1
        items.insert(item, at: min(insertIndex, items.count))
        if let current = currentIndex, insertIndex <= current {
            currentIndex = current + 1
        }
        persist()
    }

    func clear() {
        for item in items {
            if let url = item.track.streamURL?.absoluteString {
                streamExpiry.removeStream(for: url)
            }
        }
        items.removeAll()
        currentIndex = nil
        persist()
    }
}
