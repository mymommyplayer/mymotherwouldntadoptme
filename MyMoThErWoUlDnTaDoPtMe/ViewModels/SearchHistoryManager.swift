import Foundation

@MainActor
class SearchHistoryManager: ObservableObject {
    @Published var recentSearches: [String] = []

    private let historyKey = "searchHistory"
    private let maxHistory = 20

    init() {
        restore()
    }

    func add(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        recentSearches.removeAll { $0.lowercased() == trimmed.lowercased() }
        recentSearches.insert(trimmed, at: 0)
        if recentSearches.count > maxHistory {
            recentSearches = Array(recentSearches.prefix(maxHistory))
        }
        save()
    }

    func remove(_ query: String) {
        recentSearches.removeAll { $0 == query }
        save()
    }

    func clear() {
        recentSearches.removeAll()
        save()
    }

    func suggestions(for prefix: String) -> [String] {
        guard !prefix.isEmpty else { return recentSearches }
        return recentSearches.filter { $0.localizedCaseInsensitiveContains(prefix) }
    }

    private func save() {
        UserDefaults.standard.set(recentSearches, forKey: historyKey)
    }

    private func restore() {
        recentSearches = UserDefaults.standard.stringArray(forKey: historyKey) ?? []
    }
}
